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
    {-hide_fields {}}
    {-sort_order {}}
} {
    Creates a new state for a certain FSM (Finite State Machine) workflow.
    
    @param workflow_id The id of the FSM workflow to add the state to
    @param short_name
    @param pretty_name
    @param hide_fields            A space-separated list of the names of form fields which should be
                                  hidden when in this state, because they're irrelevant in a certain state.
    @param sort_order             The number which this state should be in the sort ordering sequence. 
                                  Leave blank to add state at the end. If you provide a sort_order number
                                  which already exists, existing states are pushed down one number.
    @return ID of new state.
    
    @author Peter Marklund
} {        
    db_transaction {
    
        set state_id [db_nextval "workflow_fsm_states_seq"]
        
        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order -workflow_id $workflow_id -table_name "workflow_fsm_states"]
        } else {
            set sort_order_taken_p [db_string select_sort_order_p {}]
            if { $sort_order_taken_p } {
                db_dml update_sort_order {}
            }
        }
        
        db_dml do_insert {}
    }

    # State info for the workflow changed, flush whole state cache
    workflow::state::flush_cache -workflow_id $workflow_id
 
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

ad_proc -public workflow::state::fsm::get_element {
    {-state_id:required}
    {-element:required}
} {
    Return a single element from the information about a state.

    @param state_id The ID of the workflow
    @return The element you asked for

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -state_id $state_id -array row
    return $row($element)
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

ad_proc -public workflow::state::fsm::get_workflow_id {
    {-state_id:required}
} {
    Lookup the workflow that the given state belongs to.

    @return The id of the workflow the state belongs to.

    @author Peter Marklund
} {
    return [util_memoize \
            [list workflow::state::fsm::get_workflow_id_not_cached -state_id $state_id]]
}

#####
# Private procs
#####

ad_proc -private workflow::state::fsm::get_workflow_id_not_cached {
    {-state_id:required}
} {
    This proc is used internally by the workflow API only. Use the proc
    workflow::state::fsm::get_workflow_id instead.

    @author Peter Marklund
} {
    return [db_string select_workflow_id {}]
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
    array set state { 
        hide_fields {} 
    }
    
    # Get the info from the spec
    array set state $spec

    # Create the state
    set state_id [workflow::state::fsm::new \
            -workflow_id $workflow_id \
            -short_name $short_name \
            -pretty_name $state(pretty_name) \
            -hide_fields $state(hide_fields) \
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
    foreach { short_name spec } $spec {
        workflow::state::fsm::parse_spec \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -spec $spec
    }
}

ad_proc -private workflow::state::fsm::generate_spec {
    {-state_id:required}
} {
    Generate the spec for an individual state definition.

    @param state_id The id of the state to generate spec for.
    @return spec The states spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -state_id $state_id -array row

    # Get rid of elements that shouldn't go into the spec
    array unset row short_name 
    array unset row state_id
    array unset row workflow_id
    array unset row sort_order

    # Get rid of empty strings
    foreach name [array names row] {
        if { [empty_string_p $row($name)] } {
            array unset row $name
        }
    }
    
    set spec {}
    foreach name [lsort [array names row]] {
        lappend spec $name $row($name)
    }

    return $spec
}
    
ad_proc -private workflow::state::fsm::generate_states_spec {
    {-workflow_id:required}
} {
    Generate the spec for the block containing the definition of all
    states for the workflow.

    @param workflow_id The id of the workflow to delete.
    @return The states spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # states(short_name) { ... state-spec ... }
    array set states [list]

    foreach state_id [workflow::fsm::get_states -workflow_id $workflow_id] {
        lappend states_list [get_element -state_id $state_id -element short_name] [generate_spec -state_id $state_id]
    }
    
    return $states_list

}

ad_proc -private workflow::state::flush_cache {
    {-workflow_id:required}
} {
    Flush all caches related to state information for
    the given workflow. Used internally by the workflow API
    only.

    @author Peter Marklund
} {
    # TODO: Flush request cache
    # ...

    # Flush the thread global cache
    util_memoize_flush [list workflow::state::get_all_info_not_cached -workflow_id $workflow_id]    
}

ad_proc -private workflow::state::fsm::get_all_info {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only.
    Returns all information related to states for a certain
    workflow instance. Uses util_memoize to cache values.

    @see workflow::state::fsm::get_all_info_not_cached

    @author Peter Marklund
} {
    return [util_memoize [list workflow::state::fsm::get_all_info_not_cached \
            -workflow_id $workflow_id] [workflow::cache_timeout]]
}

ad_proc -private workflow::state::fsm::get_all_info_not_cached {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only and
    should not be invoked directly from application code. Returns
    all information related to states for a certain workflow instance.
    Goes to the database on every invocation and should be used together
    with util_memoize.

    @author Peter Marklund
} {
    array set state_data {}

    # Use a list to be able to retrieve states in sort order
    set state_ids [list]
    db_foreach select_states {} -column_array state_row {
        # Cache the state_id -> workflow_id lookup

        util_memoize_seed \
                [list workflow::state::fsm::get_workflow_id_not_cached -state_id $state_row(state_id)] \
                $workflow_id

        set state_data($state_row(state_id)) [array get state_row]
        lappend state_ids $state_row(state_id)
    }
    set state_data(state_ids) $state_ids

    return [array get state_data]
}
