<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::role::add.do_insert">
    <querytext>
        insert into workflow_roles
                (role_id, workflow_id, short_name, pretty_name)
             values
                (:role_id, :workflow_id, :short_name, :pretty_name)
    </querytext>
  </fullquery>

</queryset>
