<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::state::fsm::new.do_insert">
    <querytext>
        insert into workflow_fsm_states
                (state_id, workflow_id, sort_order, short_name, pretty_name)
         values (:state_id, :workflow_id, :sort_order, :short_name, :pretty_name)
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::get.state_info">
    <querytext>
        select workflow_id,
               sort_order,
               short_name,
               pretty_name 
        from workflow_fsm_states
        where state_id = :state_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::state::fsm::get_id.select_id">
    <querytext>
        select state_id 
        from workflow_fsm_states
        where short_name = :short_name
        and   workflow_id = :workflow_id
    </querytext>
  </fullquery>

</queryset>
