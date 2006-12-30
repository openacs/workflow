<?xml version="1.0"?>
<queryset>
	
	<fullquery name="get_wfs">
	        <querytext>
		select 	pretty_name,
			workflow_id
		from workflows
		where object_id is null
		 </querytext>
	</fullquery>
</queryset>



