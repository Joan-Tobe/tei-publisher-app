xquery version "3.1";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare default element namespace "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "/db/apps/tei-publisher/modules/config.xqm";
import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";
import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util";
import module namespace odd="http://www.tei-c.org/tei-simple/odd2odd";

declare option output:method "json";
declare option output:media-type "application/json";

declare function local:models($spec as element()) {
    array {
        for $model in $spec/(model|modelGrp|modelSequence)
        return
            map {
                "type": local-name($model),
                "desc": $model/desc/string(),
                "output": $model/@output/string(),
                "behaviour": $model/@behaviour/string(),
                "predicate": $model/@predicate/string(),
                "css": $model/@cssClass/string(),
                "sourcerend": $model/@useSourceRendition = 'true',
                "renditions": local:renditions($model),
                "parameters": local:parameters($model),
                "models": local:models($model)
            }
    }
};

declare function local:parameters($model as element()) {
    array {
        for $param in $model/param
        return
            map {
                "name": $param/@name/string(),
                "value": $param/@value/string()
            }
    }
};


declare function local:renditions($model as element()) {
    array {
        for $rendition in $model/outputRendition
        return
            map {
                "scope": $rendition/@scope/string(),
                "css": replace($rendition/string(), "^\s+(.*?)\s+$", "$1")
            }
    }
};

declare function local:load($oddPath as xs:string, $root as xs:string) {
    let $odd := doc($root || "/" || $oddPath)/TEI
    let $schemaSpec := $odd//schemaSpec
    return
        map {
            "elementSpecs":
                array {
                    for $spec in $odd//elementSpec[model|modelGrp|modelSequence]
                    order by $spec/@ident
                    return
                        map {
                            "ident": $spec/@ident/string(),
                            "mode": $spec/@mode/string(),
                            "models": local:models($spec)
                        }
                },
            "namespace": $schemaSpec/@ns/string(),
            "source": $schemaSpec/@source/string(),
            "title": $odd//teiHeader/fileDesc/titleStmt/title[not(@type)]/string(),
            "titleShort": $odd//teiHeader/fileDesc/titleStmt/title[@type = 'short']/string()
        }
};

declare function local:find-spec($oddPath as xs:string, $root as xs:string, $ident as xs:string) {
    let $odd := doc($root || "/" || $oddPath)
    let $spec := $odd//elementSpec[@ident = $ident][model|modelGrp|modelSequence]
    return
        if ($spec) then
            map {
                "status": "found",
                "odd": $oddPath,
                "models": local:models($spec)
            }
        else
            let $source := $odd//schemaSpec/@source
            return
                if ($source) then
                    local:find-spec($source, $root, $ident)
                else
                    map {
                        "status": "not-found"
                    }
};


declare function local:get-line($src, $line as xs:int?) {
    if ($line) then
        let $lines := tokenize($src, "\n")
        return
            subsequence($lines, $line - 1, 3) !
                replace(., "^\s*(.*?)", "$1&#10;")
    else
        ()
};

declare function local:recompile($source as xs:string, $root as xs:string) {
    let $outputRoot := request:get-parameter("output-root", $config:output-root)
    let $outputPrefix := request:get-parameter("output-prefix", $config:output)
    let $config := doc($root || "/configuration.xml")/*
    for $module in ("web", "print", "latex", "epub")
    return
        try {
            for $file in pmu:process-odd(
                odd:get-compiled($root, $source),
                $outputRoot,
                $module,
                "../" || $outputPrefix,
                $config)?("module")
            let $src := util:binary-to-string(util:binary-doc($file))
            let $compiled := util:compile-query($src, ())
            return
                if ($compiled/*:error) then
                    map {
                        "file": $file,
                        "error": $compiled/*:error/string(),
                        "line": $compiled/*:error/@line,
                        "message": local:get-line($src, $compiled/*:error/@line)
                    }
                else
                    map {
                        "file": $file
                    }
        } catch * {
            map {
                "error": "Error for output mode " || $module,
                "message": $err:description
            }
        }
};

declare function local:save($oddPath as xs:string, $root as xs:string, $data as xs:string) {
    let $odd := doc($root || "/" || $oddPath)
    let $parsed := parse-xml($data)
    let $updated := local:update($odd, $parsed, $odd)
    let $serialized := serialize($updated,
        <output:serialization-parameters>
            <output:indent>true</output:indent>
            <output:omit-xml-declaration>false</output:omit-xml-declaration>
        </output:serialization-parameters>)
    let $stored := xmldb:store($root, $oddPath, $serialized)
    let $report :=
        array {
            local:recompile($oddPath, $root)
        }
    return
        map {
            "odd": $oddPath,
            "report": $report
        }
};

declare function local:update($nodes as node()*, $data as document-node(), $orig as document-node()) {
    for $node in $nodes
    return
        typeswitch($node)
            case document-node() return
                document {
                    local:update($node/node(), $data, $orig)
                }
            case element(TEI) return
                    element { node-name($node) } {
                        for $prefix in in-scope-prefixes($node)[. != "http://www.tei-c.org/ns/1.0"][. != ""]
                        let $namespace := namespace-uri-for-prefix($prefix, $node)
                        return
                            namespace { $prefix } { $namespace }
                        ,
                        $node/@*,
                        local:update($node/node(), $data, $orig)
                    }
            case element(titleStmt) return
                element { node-name($node) } {
                    $node/@*,
                    $data/schemaSpec/title[text()],
                    $node/* except $node/title
                }
            case element(schemaSpec) return
                element { node-name($node) } {
                    $node/@* except ($node/@ns, $node/@source),
                    (: Save namespace attribute if specified :)
                    if ($data/schemaSpec/@ns) then
                        $data/schemaSpec/@ns
                    else
                        (),
                    $data/schemaSpec/@source,
                    local:update($node/node(), $data, $orig),
                    for $spec in $data//elementSpec
                    where empty($orig//elementSpec[@ident = $spec/@ident])
                    return
                        $spec
                }
            case element(elementSpec) return
                let $newSpec := $data//elementSpec[@ident=$node/@ident]
                return
                    element { node-name($node) } {
                        $node/@ident,
                        $node/@mode,
                        $node/* except ($node/model, $node/modelGrp, $node/modelSequence),
                        $newSpec/*
                    }
            case element() return
                element { node-name($node) } {
                    $node/@*,
                    local:update($node/node(), $data, $orig)
                }
            default return
                $node
};

declare function local:lint() {
    let $code := request:get-parameter("code", ())
    let $prolog := (
        "declare variable $parameters := map {};",
        "declare variable $node := ();"
    )
    let $query := string-join($prolog) || "&#10;" || $code
    let $r := util:compile-query($query, ())
    let $error := $r/*:error
    return
        if ($r/@result = 'fail') then
            let $msg := $error/string()
            let $analyzed := analyze-string($msg, ".*line:?\s(\d+).*?column\s(\d+)")
            let $analyzed :=
                if ($analyzed//fn:group) then
                    $analyzed
                else
                    analyze-string($msg, "line\s(\d+):(\d+)")
            let $parsedLine := $analyzed//fn:group[1]
            let $parsedColumn := $analyzed//fn:group[2]
            let $line :=
                if ($parsedLine) then
                    number($parsedLine)
                else
                    number($error/@line)
            let $column :=
                if ($parsedColumn) then
                    number($parsedColumn)
                else
                    number($error/@column)
            return
                map {
                    "status": "fail",
                    "line": $line - 1,
                    "column": $column,
                    "message": $error/string()
                }
        else
            map {
                "status": "pass"
            }
};


let $action := request:get-parameter("action", "load")
let $oddPath := request:get-parameter("odd", ())
let $root := request:get-parameter("root", $config:odd-root)
let $data := request:get-parameter("data", ())
let $ident := request:get-parameter("ident", ())
return
    switch ($action)
        case "save" return
            local:save($oddPath, $root, $data)
        case "find" return
            local:find-spec($oddPath, $root, $ident)
        case "lint" return
            local:lint()
        default return
            local:load($oddPath, $root)