<cfsetting requesttimeout="300">
<cfinclude template="_testHelper.cfm">
<cfscript>
	tests = ["test_smoke.cfm", "test_resize.cfm", "test_rotate.cfm", "test_crop.cfm", "test_watermark.cfm", "test_format.cfm", "test_fluent.cfm", "test_errors.cfm", "test_exif_passthrough.cfm"];
	totalPasses = 0;
	totalFailures = [];
</cfscript>
<cfoutput>
<!doctype html><meta charset='utf-8'><title>Thumbnailator - all tests</title>
<style>
	body{font-family:monospace}
	h2{margin-top:2em;border-top:2px solid ##ccc;padding-top:1em}
	.serverinfo{background:##f4f4f4;border:1px solid ##ccc;padding:0.6em 0.8em;margin:0.6em 0 1.4em;font-size:0.95em;color:##333}
</style>
<h1>Thumbnailator - full test suite</h1>
<div class="serverinfo">#encodeForHTML(serverInfo())#</div>
<cfloop array="#tests#" index="t">
	<h2>#t#</h2>
	<cftry>
		<cfinclude template="#t#">
		<cfcatch type="any">
			<cfscript>
				request.passes = (structKeyExists(request, "passes") ? request.passes : 0);
				request.failures = (structKeyExists(request, "failures") ? request.failures : []);
				arrayAppend(request.failures, "ABORTED: " & cfcatch.message);
				writeOutput("<div style='color:red;font-weight:bold'>ABORTED " & encodeForHTML(cfcatch.message) & "</div>");
				writeOutput("<pre style='color:##600;background:##fee;padding:0.4em'>" & encodeForHTML(cfcatch.detail) & "</pre>");
			</cfscript>
		</cfcatch>
	</cftry>
	<cfscript>
		totalPasses += request.passes;
		for (f in request.failures) arrayAppend(totalFailures, t & ": " & f);
		request.passes = 0;
		request.failures = [];
	</cfscript>
</cfloop>
<hr><h2 style="border:none">Aggregate: #totalPasses# passed, #arrayLen(totalFailures)# failed</h2>
<cfif arrayLen(totalFailures)>
	<cfset getPageContext().getResponse().setStatus(500)>
	<ul>
		<cfloop array="#totalFailures#" index="f"><li>#encodeForHTML(f)#</li></cfloop>
	</ul>
</cfif>
</cfoutput>
