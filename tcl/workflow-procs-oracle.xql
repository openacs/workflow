<?xml version="1.0"?>
<queryset>
  <rdbms><type>oracle</type><version>8.1.7</version></rdbms>

  <fullquery name="workflow::new.do_insert">
    <querytext>
        workflow.new (
            :short_name,
            :pretty_name,
            :package_key,            
            :object_id,
            :object_type,
            :creation_user,
            :creation_ip,
            :context_id
        );
    </querytext>
  </fullquery>

  <fullquery name="workflow::delete.do_delete">
    <querytext>
        acs_object.delete(:workflow_id) from dual;
    </querytext>
  </fullquery>

</queryset>
