ad_library {
    Procedures in the workflow::fsm::state namespace and
    in its child namespaces.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::state::fsm {}

#####
#
#  workflow::state::fsm namespace
#
#####

ad_proc -public workflow::state::fsm::new {
    {-workflow_id:required}
    {-short_name:required}
    {-pretty_name:required}
    {-sort_order {}}
} {
    Creates a new state for a certain FSM (Finite State Machine) workflow.
    
    @param workflow_id The id of the FSM workflow to add the state to
    @param short_name
    @param pretty_name
    @return ID of new state.
    
    @author Peter Marklund
} {        
    db_transaction {
    
        set state_id [db_nextval "workflow_fsm_states_seq"]
        
        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order -workflow_id $workflow_id -table_name "workflow_fsm_states"]
        }
        
        db_dml do_insert {}
    }
    return $state_id
}

ad_proc -public workflow::state::fsm::get {
    {-state_id:required}
    {-array:required}
} {
    Return workflow_id, sort_order, short_name, and pretty_name for a certain
    FSM workflow state.

    @author Peter Marklund
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    db_1row state_info {} -column_array row
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


ad_proc -private workflow::state::fsm::parse_spec {
    {-workflow_id:required}
    {-short_name:required}
    {-spec:required}
} {
    Parse the spec for an individual state definition.

    @param workflow_id The id of the workflow to delete.
    @param short_name The short_name of the state
    @param spec The state spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Initialize array with default values
    array set state {}
    
    # Get the info from the spec
    array set state $spec

    # Create the state
    set state_id [workflow::state::fsm::new \
            -workflow_id $workflow_id \
            -short_name $short_name \
            -pretty_name $state(pretty_name)
            ]
}

ad_proc -private workflow::state::fsm::parse_states_spec {
    {-workflow_id:required}
    {-spec:required}
} {
    Parse the spec for the block containing the definition of all
    states for the workflow.

    @param workflow_id The id of the workflow to delete.
    @param spec The states spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # states(short_name) { ... state-spec ... }
    array set states $spec

    foreach short_name [array names states] {
        workflow::state::fsm::parse_spec \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -spec $states($short_name)
    }
}
