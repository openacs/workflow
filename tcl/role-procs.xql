<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::role::insert.do_insert">
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

  <fullquery name="workflow::role::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order)) + 1
        from   workflow_role_callbacks
        where  role_id = :role_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::role::callback_insert.insert_rule">
    <querytext>
        insert into workflow_role_callbacks (role_id, acs_sc_impl_id, sort_order)
        values (:role_id, :acs_sc_impl_id, :sort_order)
    </querytext>
  </fullquery>



</queryset>
