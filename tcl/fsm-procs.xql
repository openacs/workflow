<?xml version="1.0"?>
<queryset>

  <fullquery name="workflow::fsm::state::add.do_insert">
    <querytext>
        insert into workflow_fsm_states
                (state_id, workflow_id, sort_order, short_name, pretty_name)
         values (:state_id, :workflow_id, :sort_order, :short_name, :pretty_name)
    </querytext>
  </fullquery>

  <fullquery name="workflow::fsm::state::get_id.select_id">
    <querytext>
        select state_id 
        from workflow_fsm_states
        where short_name = :short_name
        and   workflow_id = :workflow_id
    </querytext>
  </fullquery>

  <fullquery name="workflow::fsm::action::add.insert_fsm_action">
    <querytext>
        insert into workflow_fsm_actions
                (action_id, new_state)
            values
                (:action_id, :new_state_id)        
    </querytext>
  </fullquery>

  <fullquery name="workflow::fsm::action::add.insert_enabled_state">
    <querytext>
        insert into workflow_fsm_action_enabled_in_states
                (action_id, state_id)
         values (:action_id, :enabled_state_id)
    </querytext>
  </fullquery>

</queryset>
