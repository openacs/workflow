ad_library {
    Procedures in the workflow::fsm namespace and
    in its child namespaces.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval ::workflow::fsm {}
    
ad_proc -public ::workflow::fsm::set_initial_state {
    {-workflow_id:required}
    {-initial_state:required}
} {
    Set the initial state of an FSM (Finite State Machine) workflow.

    @param workflow_id     The id of the workflow to set initial state for.
    @param initial_state   The id of the initial state of the workflow

    @author Peter Marklund
} {
    db_dml do_insert {}
}


namespace eval ::workflow::fsm::state {}

ad_proc -public ::workflow::fsm::state::add {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-sort_order ""}
} {
    Creates a new state for a certain FSM (Finite State Machine) workflow.
    
    @param workflow_id The id of the FSM workflow to add the state to
    @param short_name
    @param pretty_name
    
    @author Peter Marklund
} {        
    set state_id [db_nextval "wf_workflow_fsm_states_seq"]

    db_dml do_insert {}
}

ad_proc -public ::workflow::fsm::state::id_from_short_name {
    short_name
} {
    Return the id of the state with given short name

    @param short_name The name of the state to return the id for.

    @author Peter Marklund
} {
    return [db_string id_from_name {}]
}

namespace eval ::workflow::fsm::action {}

ad_proc -public ::workflow::fsm::action::add {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-allowed_roles {}}
    {-assigned_role {}}
    {-privileges {}}
    {-enabled_states {}}
    {-new_state {}}
} {
    Add an action to a certain FSM (Finite State Machine) workflow. This procedure
    invokes the generic workflow::action::add procedures and does additional inserts
    for FSM specific information. See the parameter
    documentation for the proc workflow::action::add.

    @param enabled_states         The short names of states in which the 
                                  action is enabled.
    @param new_state              The state that a workflow case moves to 
                                  when the action is taken. Optional.

    @see workflow::action::add

    @author Peter Marklund
} {        

    db_transaction {
        # Generic workflow data:
        set action_id [workflow::action::add -workflow_id $workflow_id
                                             -short_name $short_name
                                             -pretty_name $pretty_name
                                             -pretty_past_tense $pretty_past_tense 
                                             -allowed_roles $allowed_roles 
                                             -assigned_role $assigned_role 
                                             -privileges $privileges]

        # FSM specific data:

        # Record whether the action changes state
        db_dml insert_fsm_action {}

        # Record in which states the action is enabled
        foreach state_short_name $enabled_states {
            set enabled_state_id [workflow::fsm::state::id_from_short_name $state_short_name]
            db_dml insert_enabled_state {}
        }
    }   
}
