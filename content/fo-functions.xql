xquery version "3.1";

(:~
 : Function module to produce HTML output. The functions defined here are called 
 : from the generated XQuery transformation module. Function names must match
 : those of the corresponding TEI Processing Model functions.
 : 
 : @author Wolfgang Meier
 :)
module namespace pmf="http://www.tei-c.org/tei-simple/xquery/functions/fo";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace console="http://exist-db.org/xquery/console" at "java:org.exist.console.xquery.ConsoleModule";

declare variable $pmf:CSS_PROPERTIES := (
    "font-family", 
    "font-weight",
    "font-style",
    "font-size",
    "font-variant",
    "text-align", 
    "text-decoration",
    "line-height",
    "color",
    "background-color",
    "space-after",
    "space-before",
    "keep-with-next",
    "margin-top",
    "margin-bottom",
    "margin-left",
    "margin-right"
);

declare function pmf:paragraph($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:block>
    {
        pmf:check-styles($config, $class, ()),
        comment { "paragraph" || " (" || $class || ")"},
        pmf:apply-children($config, $node, $content)
    }
    </fo:block>
};

declare function pmf:heading($config as map(*), $node as element(), $class as xs:string, $content as node()*, $type, $subdiv) {
    let $level := count($content/ancestor::tei:div)
    let $defaultStyle := $config?default-styles("head" || $level)
    return
        <fo:block>
        {
            pmf:check-styles($config, $class, $defaultStyle),
            comment { "heading level " || $level || " (" || $class || ")"},
            pmf:apply-children($config, $node, $content)
        }
        </fo:block>
};

declare function pmf:list($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    let $label-length :=
        if ($node/tei:label) then
            max($node/tei:label ! string-length(.))
        else
            1
    return
        <fo:list-block provisional-distance-between-starts="{$label-length}em">
            {$config?apply($config, $content)}
        </fo:list-block>
};

declare function pmf:listItem($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:list-item>
        <fo:list-item-label>
        {
            if ($node/preceding-sibling::tei:label) then
                <fo:block>{$config?apply($config, $node/preceding-sibling::tei:label[1])}</fo:block>
            else
                <fo:block/>
        }
        </fo:list-item-label>
        <fo:list-item-body start-indent="body-start()">
            <fo:block>{pmf:apply-children($config, $node, $content)}</fo:block>
        </fo:list-item-body>
    </fo:list-item>
};

declare function pmf:block($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:block>
    {
        pmf:check-styles($config, $class, ()),
        pmf:apply-children($config, $node, $content)
    }
    </fo:block>
};

declare function pmf:note($config as map(*), $node as element(), $class as xs:string, $content as item()*, $place as xs:string?) {
    let $number := count($node/preceding::tei:note)
    return
        <fo:footnote>
            <fo:inline keep-with-previous.within-line="always" baseline-shift="super" font-size="60%">
            {$number} 
            </fo:inline>
            <fo:footnote-body start-indent="0mm" end-indent="0mm" text-indent="0mm" white-space-treatment="ignore-if-surrounding-linefeed">
                <fo:list-block>
                    <fo:list-item>
                        <fo:list-item-label end-indent="label-end()" >
                            <fo:block font-size=".60em">
                            { $number }
                            </fo:block>
                        </fo:list-item-label>
                        <fo:list-item-body start-indent="body-start()">
                            <fo:block font-size=".85em">{pmf:apply-children($config, $node, $content)}</fo:block>
                        </fo:list-item-body>
                    </fo:list-item>
                </fo:list-block>
            </fo:footnote-body>
        </fo:footnote>
};

declare function pmf:section($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    pmf:apply-children($config, $node, $content)
};

declare function pmf:anchor($config as map(*), $node as element(), $class as xs:string, $id as item()*) {
    ()
};

declare function pmf:link($config as map(*), $node as element(), $class as xs:string, $content as node()*, $url as xs:anyURI?) {
    if (starts-with($url, "#")) then
        <fo:basic-link internal-destination="{substring-after($url, '#')}">
        {pmf:apply-children($config, $node, $content)}
        </fo:basic-link>
    else
        <fo:basic-link external-destination="{$url}">{pmf:apply-children($config, $node, $content)}</fo:basic-link>
};

declare function pmf:escapeChars($text as item()) {
    $text
};

declare function pmf:glyph($config as map(*), $node as element(), $class as xs:string, $content as xs:anyURI?) {
    if ($content = "char:EOLhyphen") then
        "&#xAD;"
    else
        ()
};

declare function pmf:graphic($config as map(*), $node as element(), $class as xs:string, $url as xs:anyURI,
    $width, $height, $scale) {
    let $base :=
        if (matches($url, "^\w+://")) then
            $url
        else
            request:get-scheme() || "://" || request:get-server-name() || ":" || request:get-server-port() ||
            request:get-context-path() || "/rest/" || util:collection-name($node)
    return
        <fo:external-graphic src="url({$base}/{$url})" scaling="uniform">
        {
             pmf:check-styles($config, $class, $config?default-styles($class))
        }
        { comment { $class } }
        </fo:external-graphic>
};

declare function pmf:inline($config as map(*), $node as element(), $class as xs:string, $content as item()*) {
    <fo:inline>
    {
        pmf:check-styles($config, $class, ()),
        pmf:apply-children($config, $node, $content)
    }
    </fo:inline>
};

declare function pmf:text($config as map(*), $node as element(), $class as xs:string, $content as item()*) {
    string($content)
};

declare function pmf:cit($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    pmf:inline($config, $node, $class, $content)
};

declare function pmf:body($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:block>
    {
        pmf:check-styles($config, $class, ()),
        pmf:apply-children($config, $node, $content)
    }
    </fo:block>
};

declare function pmf:index($config as map(*), $node as element(), $class as xs:string, $content as node()*, $type as xs:string) {
    ()
};

declare function pmf:omit($config as map(*), $node as element(), $class as xs:string) {
    ()
};

declare function pmf:break($config as map(*), $node as element(), $class as xs:string, $type as xs:string, $label as item()*) {
    <fo:block/>
};

declare function pmf:document($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    let $odd := doc($config?odd)
    let $config := pmf:load-styles(pmf:load-default-styles($config), $odd)
    return
     <fo:root xmlns:fo="http://www.w3.org/1999/XSL/Format">
        <fo:layout-master-set>
            <fo:simple-page-master master-name="page-left" page-height="297mm" page-width="210mm">
                { pmf:check-styles($config, $class || ":left", $config?default-styles($class || ":left"))}
                <fo:region-body margin-bottom="10mm" margin-top="16mm"/>
                <fo:region-before region-name="head-left" extent="10mm"/>
            </fo:simple-page-master>
            <fo:simple-page-master master-name="page-right" page-height="297mm" page-width="210mm">
                { pmf:check-styles($config, $class || ":right", $config?default-styles($class || ":right"))}
                <fo:region-body margin-bottom="10mm" margin-top="16mm"/>
                <fo:region-before region-name="head-right" extent="10mm"/>
            </fo:simple-page-master>
            <fo:page-sequence-master master-name="page-content">
                <fo:repeatable-page-master-alternatives>
                    <fo:conditional-page-master-reference 
                        master-reference="page-right" odd-or-even="odd"/>
                    <fo:conditional-page-master-reference 
                        master-reference="page-left" odd-or-even="even"/>
                </fo:repeatable-page-master-alternatives>
            </fo:page-sequence-master>
        </fo:layout-master-set>
        <fo:page-sequence master-reference="page-content">
            <fo:static-content flow-name="head-left">
                <fo:block margin-bottom="0.7mm" text-align-last="justify" font-family="serif"
                    font-size="10pt">
                    <fo:page-number/>
                    <fo:leader/>
                    <fo:retrieve-marker retrieve-class-name="heading"/>
                </fo:block>
            </fo:static-content>
            <fo:static-content flow-name="head-right">
                <fo:block margin-bottom="0.7mm" text-align-last="justify" font-family="serif"
                    font-size="10pt">
                    <fo:retrieve-marker retrieve-class-name="heading"/>
                    <fo:leader/>
                    <fo:page-number/>
                </fo:block>
            </fo:static-content>
            <!--fo:static-content flow-name="xsl-footnote-separator">
                <fo:block margin-top="4mm"/>
            </fo:static-content-->
            <fo:static-content flow-name="xsl-footnote-separator">
                <fo:block text-align-last="justify" margin-top="4mm" space-after="2mm">
                    <fo:leader leader-length="40%" rule-thickness="2pt" leader-pattern="rule" color="grey"/>
                </fo:block>
            </fo:static-content>
            <fo:flow flow-name="xsl-region-body" hyphenate="true" language="en" xml:lang="en">
                {pmf:apply-children($config, $node, $content)}
            </fo:flow>                         
        </fo:page-sequence>
    </fo:root>
};

declare function pmf:metadata($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    ()
};

declare function pmf:title($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    ()
};

declare function pmf:table($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:table>
        { pmf:check-styles($config, $class, ()) }
        <fo:table-body>
        { $config?apply($config, $node/tei:row) }
        </fo:table-body>
    </fo:table>
};

declare function pmf:row($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:table-row>
    { pmf:apply-children($config, $node, $content) }
    </fo:table-row>
};

declare function pmf:cell($config as map(*), $node as element(), $class as xs:string, $content as node()*) {
    <fo:table-cell>
        {
            if ($node/@cols) then
                attribute number-columns-spanned { $node/@cols }
            else
                (),
            if ($node/@rows) then
                attribute number-rows-spanned { $node/@rows }
            else
                ()
        }
        <fo:block>
        {pmf:apply-children($config, $node, $content)}
        </fo:block>
    </fo:table-cell>
};

declare function pmf:alternate($config as map(*), $node as element(), $class as xs:string, $option1 as node()*,
    $option2 as node()*) {
    pmf:apply-children($config, $node, $option1)
};

declare function pmf:get-rendition($node as node()*, $class as xs:string) {
    let $rend := $node/@rendition
    return
        if ($rend) then
            if (starts-with($rend, "#")) then
                'document_' || substring-after(.,'#')
            else if (starts-with($rend,'simple:')) then
                translate($rend,':','_')
            else
                $rend
        else
            $class
};

declare function pmf:get-before($config as map(*), $class as xs:string) {
    let $before := $config?styles?($class || ":before")?content
    return
        if ($before) then <fo:inline>{$before}</fo:inline> else ()
};

declare function pmf:get-after($config as map(*), $class as xs:string) {
    let $after := $config?styles?($class || ":after")?content
    return
        if ($after) then <fo:inline>{$after}</fo:inline> else ()
};

declare function pmf:check-styles($config as map(*), $class as xs:string, $default as map(*)?) {
    let $defaultStyles :=
        if (exists($default)) then
            $default
        else
            $config?default-styles($class)
    let $customStyles := $config?styles?($class)
    let $styles := 
        if (exists($customStyles)) then
            pmf:merge-maps($customStyles, $defaultStyles)
        else
            $default
    return
        if (exists($styles)) then
            for $style in $styles?*[. = $pmf:CSS_PROPERTIES]
            return
                attribute { $style } { $styles($style) }
        else
            ()
};

declare %private function pmf:merge-maps($map as map(*), $defaults as map(*)?) {
    if (empty($defaults)) then
        $map
    else if (empty($map)) then
        $defaults
    else
        map:new(($defaults, $map))
};

declare function pmf:load-styles($config as map(*), $root as document-node()) {
    let $css := pmf:generate-css($root)
    let $styles := pmf:parse-css($css)
    return
        map:new(($config, map:entry("styles", $styles)))
};

declare function pmf:load-default-styles($config as map(*)) {
    let $path := $config?collection || "/styles.fo.css"
    let $log := console:log($path)
    let $userStyles := pmf:read-css($path)
    let $systemStyles := pmf:read-css(system:get-module-load-path() || "/styles.fo.css")
    let $log := console:log(serialize(pmf:merge-maps($userStyles, $systemStyles), 
            <output:serialization-parameters>
                <output:method>json</output:method>
            </output:serialization-parameters>))
    return
        map:new(($config, map:entry("default-styles", pmf:merge-maps($userStyles, $systemStyles))))
};

declare function pmf:read-css($path) {
	if (util:binary-doc-available($path)) then
        let $css := util:binary-to-string(util:binary-doc($path))
        return
            pmf:parse-css($css)
    else
        ()
};

declare function pmf:parse-css($css as xs:string) {
    map:new(
        let $analyzed := analyze-string($css, "\.(.*?)\s*\{\s*([^\}]*?)\s*\}", "m")
        for $match in $analyzed/fn:match
        let $selector := $match/fn:group[@nr = "1"]/string()
        let $styles := map:new(
            for $match in analyze-string($match/fn:group[@nr = "2"], "\s*(.*?)\s*\:\s*(.*?)\;")/fn:match
            return
                map:entry($match/fn:group[1]/string(), $match/fn:group[2]/string())
        )
        return
            map:entry($selector, $styles)
    )
};

declare %private function pmf:generate-css($root as document-node()) {
    string-join((
        for $rend in $root//tei:rendition[@xml:id][not(parent::tei:model)]
        return
            "&#10;.simple_" || $rend/@xml:id || " { " || 
            normalize-space($rend/string()) || " }",
        "&#10;",
        for $model in $root//tei:model[tei:rendition]
        let $spec := $model/ancestor::tei:elementSpec[1]
        let $count := count($spec//tei:model)
        for $rend in $model/tei:rendition
        let $className :=
            if ($count > 1) then
                $spec/@ident || count($model/preceding::tei:model[. >> $spec]) + 1
            else
                $spec/@ident/string()
        let $class :=
            if ($rend/@scope) then
                $className || ":" || $rend/@scope
            else
                $className
        return
            "&#10;." || $class || " { " ||
            normalize-space($rend) || " }"
    ))
};

declare %private function pmf:apply-children($config as map(*), $node as element(), $content as item()*) {
    $content ! (
        typeswitch(.)
            case element() return
                $config?apply($config, ./node())
            default return
                string(.)
    )
};

declare function pmf:escapeChars($text as item()) {
    $text
};