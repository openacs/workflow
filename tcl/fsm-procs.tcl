ad_library {
    Procedures in the workflow::fsm namespace and
    in its child namespaces.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::fsm {}
namespace eval workflow::state::fsm {}

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
#  workflow::state::fsm namespace
#
#####

ad_proc -public workflow::state::fsm::new {
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

ad_proc -public workflow::state::fsm::get {
    {-state_id:required}
} {
    Return workflow_id, sort_order, short_name, and pretty_name for a certain
    FSM workflow state.

    @author Peter Marklund
} {
    db_1row state_info {} -column_array state_info

    return [array get state_info]
}

ad_proc -public workflow::state::fsm::get_id {
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
