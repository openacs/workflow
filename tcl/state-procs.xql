<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::state::fsm::new.select_sort_order_p">
    <querytext>
        select count(*)
        from   workflow_fsm_states
        where  workflow_id = :workflow_id
        and    sort_order = :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::new.update_sort_order">
    <querytext>
        update workflow_fsm_states
        set    sort_order = sort_order + 1
        where  workflow_id = :workflow_id
        and    sort_order >= :sort_order
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::new.do_insert">
    <querytext>
        insert into workflow_fsm_states
                (state_id, workflow_id, sort_order, short_name, pretty_name, hide_fields)
         values (:state_id, :workflow_id, :sort_order, :short_name, :pretty_name, :hide_fields)
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::get.state_info">
    <querytext>
        select state_id,
               workflow_id,
               sort_order,
               short_name,
               pretty_name,
               hide_fields
        from   workflow_fsm_states
        where  state_id = :state_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::get_id.select_id">
    <querytext>
        select state_id 
        from   workflow_fsm_states
        where  short_name = :short_name
        and    workflow_id = :workflow_id
    </querytext>
  </fullquery>

</queryset>
