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

  <fullquery name="workflow::get.workflow_info">
    <querytext>
      select workflow_id,
             short_name,
             pretty_name,
             object_id,
             package_key,
             object_type
      from   workflows
      where  workflow_id = :workflow_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::get.workflow_callbacks">
    <querytext>
        select impl.impl_owner_name || '.' || impl.impl_name
        from   acs_sc_impls impl,
               workflow_callbacks c
        where  c.workflow_id = :workflow_id
        and    impl.impl_id = c.acs_sc_impl_id
        order  by c.sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::get_id.select_workflow_id_by_package_key">
    <querytext>
      select workflow_id
      from   workflows
      where  package_key = :package_key
      and    short_name = :short_name                        
      and    object_id is null
    </querytext>
  </fullquery>

  <fullquery name="workflow::get_initial_action.select_initial_action">
    <querytext>
      select action_id
      from   workflow_initial_action
      where  workflow_id = :workflow_id
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::get_roles.select_role_ids">
    <querytext>
      select role_id
      from   workflow_roles
      where  workflow_id = :workflow_id
      order  by sort_order
    </querytext>
  </fullquery>
  
  <fullquery name="workflow::get_actions.select_action_ids">
    <querytext>
      select action_id
      from   workflow_actions
      where  workflow_id = :workflow_id
      order by sort_order
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
        select coalesce(max(sort_order),0) + 1
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

  <fullquery name="workflow::fsm::get_states.select_state_ids">
    <querytext>
      select state_id
      from   workflow_fsm_states
      where  workflow_id = :workflow_id
      order by sort_order
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
