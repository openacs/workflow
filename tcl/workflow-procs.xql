<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::get_id.select_workflow_id_by_object_id">
    <querytext>
      select workflow_id
      from   workflows
      where  object_id = :object_id
      and    short_name = :short_name                        
    </querytext>
  </fullquery>

  <fullquery name="workflow::get_id.select_workflow_id_by_package_key">
    <querytext>
      select workflow_id
      from   workflows
      where  package_key = :package_key
      and    short_name = :short_name                        
    </querytext>
  </fullquery>

  <fullquery name="workflow::get_initial_action.select_initial_action">
    <querytext>
      select action_id
      from   workflow_initial_action
      where  workflow_id = :workflow_id
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::default_sort_order.max_sort_order">
    <querytext>
        select max(sort_order)
        from   $table_name
        where  workflow_id = :workflow_id
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::callback_insert.select_sort_order">
    <querytext>
        select coalesce(max(sort_order)) + 1
        from   workflow_callbacks
        where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::callback_insert.insert_callback">
    <querytext>
        insert into workflow_callbacks (workflow_id, acs_sc_impl_id, sort_order)
        values (:workflow_id, :acs_sc_impl_id, :sort_order)
    </querytext>
  </fullquery>

  <fullquery name="workflow::service_contract::get_impl_id.select_impl_id">
    <querytext>
        select impl_id
        from   acs_sc_impls
        where  impl_owner_name = :impl_owner_name
        and    impl_name = :impl_name
    </querytext>
  </fullquery>

</queryset>
