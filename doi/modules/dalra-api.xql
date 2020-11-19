xquery version "3.1";

module namespace doi = "http://existsolutions.com/app/doi";
import module namespace errors = "http://exist-db.org/xquery/router/errors";

import module namespace http = "http://expath.org/ns/http-client";

(:  
    Testsystem:
        https://labs.da-ra.de/dara/mydara?lang=en 
        Username: dipf2
        Passwort: labs_dipf#2019
    DOI Registration: 
        https://www.da-ra.de/en/technical-information/doi-registration/#c1203
    API
        https://labs.da-ra.de/apireference/#/DOI/getResourceIdentifier 
  :)
  
declare variable $doi:username := "dipf2";
declare variable $doi:password := "labs_dipf#2019";


declare function doi:get-resource-identifier($doi) {
    let $request := 
        <http:request 
            href="https://labs.da-ra.de/dara/api/getResourceIdentifier?doi={encode-for-uri($doi)}"
            method="get"
            username="{ $doi:username }"
            password="{ $doi:password }"
            auth-method="basic"
            send-authorization="true">
            <http:header name="accept" value="application/json"/>
        </http:request>
    
    let $response := http:send-request($request)
    return
        if($response[1]/@status = 200 or $response[1]/@status = 201)
        then (
            let $json := util:binary-to-string($response[2])
            return
                json-to-xml($json)     
        )  else (
            <error status="{$response[1]/@status}">
                {
                    $response[1],
                    if(exists($response[2]))
                    then (
                        let $json := util:binary-to-string($response[2])
                        return
                            json-to-xml($json)     
                    )
                    else () 
                }
            </error>
        )
};


(:
  register (create) or update a DOI by using registrar service (DARA API)
  
  @param $resource the DOI metadata for the resource to be registered
  @param $registration boolean value - if true() a new DOI will be created for the resource
:)
declare function doi:create-update-resource($resource, $registration) {

    let $request := 
        <http:request method="post" username="{$doi:username}" password="{$doi:password}" auth-method="basic"
                send-authorization="true">
                    <http:body media-type='application/xml'/>
                    <http:header name="accept" value="application/json"/>
        </http:request>
    
    let $response := http:send-request($request,
                                        "https://labs.da-ra.de/dara/study/importXML?registration=" || $registration,
                                        $resource)
    
    let $log := util:log('info',util:binary-to-string($response[2]))
    
    let $status := $response[1]/@status
    let $json := parse-json(util:binary-to-string($response[2]))
    return
        if($status = 200 or $status = 201)
        then $json
        else if($status = 400) then
            error($errors:BAD_REQUEST, $json?errors?detail)
        else if($status = 401) then
            error($errors:UNAUTHORIZED,$json?message)
        else if($status = 403) then
            error($errors:FORBIDDEN, $json?errors?detail)
        else
            error(xs:QName("errors:SERVER_ERROR_500"),"internal Server Error at DOI Registrar")
};