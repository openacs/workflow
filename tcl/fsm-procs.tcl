ad_library {
    Procedures in the workflow::fsm namespace and
    in its child namespaces.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::fsm {}
namespace eval workflow::fsm::state {}
namespace eval workflow::fsm::action {}

#####
#
#  workflow::fsm namespace
#
#####
    
ad_proc -public workflow::fsm::delete {
    {-workflow_id:required}
} {
    Delete an FSM workflow and all data attached to it (states, actions etc.).

    @param workflow_id The id of the FSM workflow to delete.

    @author Peter Marklund
} {
    # All FSM data hangs on the generic workflow data and will be deleted on cascade
    workflow::delete $workflow_id
}

#####
#
#  workflow::fsm::state namespace
#
#####

ad_proc -public workflow::fsm::state::add {
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
    set state_id [db_nextval "workflow_fsm_states_seq"]

    if { [empty_string_p $sort_order] } {
        set sort_order [workflow::default_sort_order -workflow_id $workflow_id workflow_fsm_states]
    }

    db_dml do_insert {}
}

ad_proc -public workflow::fsm::state::get_id {
    {-workflow_id:required}
    {-short_name:required}
} {
    Return the id of the state with given short name

    @param workflow_id The id of the workflow the state belongs to.
    @param short_name The name of the state to return the id for.

    @author Peter Marklund
} {
    return [db_string select_id {}]
}

#####
#
#  workflow::fsm::action namespace
#
#####

ad_proc -public workflow::fsm::action::add {
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
    @param new_state              The name of the state that a workflow case moves to 
                                  when the action is taken. Optional.

    @see workflow::action::add

    @author Peter Marklund
} {        

    db_transaction {
        # Generic workflow data:
        set action_id [workflow::action::add -workflow_id $workflow_id \
                                             -short_name $short_name \
                                             -pretty_name $pretty_name \
                                             -pretty_past_tense $pretty_past_tense \
                                             -allowed_roles $allowed_roles \
                                             -assigned_role $assigned_role \
                                             -privileges $privileges]

        # FSM specific data:

        # Record whether the action changes state
        if { ![empty_string_p $new_state] } {
            set new_state_id [workflow::fsm::state::get_id -workflow_id $workflow_id \
                                                           -short_name $new_state]
        } else {
            set new_state_id [db_null]
        }
        db_dml insert_fsm_action {}

        # Record in which states the action is enabled
        foreach state_short_name $enabled_states {
            set enabled_state_id [workflow::fsm::state::get_id -workflow_id $workflow_id \
                                                               -short_name $state_short_name]
            db_dml insert_enabled_state {}
        }
    }   
}
