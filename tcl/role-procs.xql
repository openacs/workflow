<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::role::new.do_insert">
    <querytext>
        insert into workflow_roles
                (role_id, workflow_id, short_name, pretty_name)
             values
                (:role_id, :workflow_id, :short_name, :pretty_name)
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::get_id.select_role_id">
    <querytext>
        select role_id 
        from workflow_roles 
        where workflow_id = :workflow_id 
        and short_name = :short_name
    </querytext>
  </fullquery>

</queryset>
