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
    {-internal:boolean}
    {-short_name {}}
    {-pretty_name:required}
    {-hide_fields {}}
    {-sort_order {}}
} {
    Creates a new state for a certain FSM (Finite State Machine) workflow.
    
    @param workflow_id The id of the FSM workflow to add the state to

    @param short_name             If you leave blank, the short_name will be generated from pretty_name.

    @param pretty_name

    @param hide_fields            A space-separated list of the names of form fields which should be
                                  hidden when in this state, because they're irrelevant in a certain state.

    @param sort_order             The number which this state should be in the sort ordering sequence. 
                                  Leave blank to add state at the end. If you provide a sort_order number
                                  which already exists, existing states are pushed down one number.

    @param internal     Set this flag if you're calling this proc from within the corresponding proc 
                        for a particular workflow model. Will cause this proc to not flush the cache 
                        or call workflow::definition_changed_handler, which the caller must then do.

    @return ID of new state.
    
    @author Peter Marklund
} {        
    db_transaction {
    
        set state_id [db_nextval "workflow_fsm_states_seq"]
        
        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order \
                                -workflow_id $workflow_id \
                                -table_name "workflow_fsm_states"]
        } else {
            workflow::state::fsm::update_sort_order \
                -workflow_id $workflow_id \
                -sort_order $sort_order
        }

        set short_name [workflow::state::fsm::generate_short_name \
                            -workflow_id $workflow_id \
                            -pretty_name $pretty_name \
                            -short_name $short_name]
        
        db_dml do_insert {}

        if { !$internal_p } {
            workflow::definition_changed_handler -workflow_id $workflow_id
        }
    }

    if { !$internal_p } {
        workflow::flush_cache -workflow_id $workflow_id
    }
 
    return $state_id
}


ad_proc -public workflow::state::fsm::edit {
    {-state_id:required}
    {-array:required}
    {-workflow_id {}}
    {-internal:boolean}
} {
    Creates a new state for a certain FSM (Finite State Machine) workflow.
    
    @param state_id     The id of the FSM state you wish to edit

    @param workflow_id  Optionally specify the workflow_id. If not specified, we will execute a query to find it.
    
    @param array        Name of an array in the caller's namespace with attributes to edit.

    @param internal     Set this flag if you're calling this proc from within the corresponding proc 
                        for a particular workflow model. Will cause this proc to not flush the cache 
                        or call workflow::definition_changed_handler, which the caller must then do.

    @return ID of the state.
    
    @author Peter Marklund
} {        
    upvar 1 $array row
    if { ![array exists row] } {
        error "Array $array does not exist or is not an array"
    }
    foreach name [array names row] {
        set missing_elm($name) 1
    }

    if { [empty_string_p $workflow_id] } {
        set workflow_id [workflow::state::fsm::get_element \
                             -state_id $state_id \
                             -element workflow_id]
    }

    set set_clauses [list]

    # Handle columns in the workflow_fsm_states table
    foreach attr { 
        short_name pretty_name hide_fields sort_order
    } {
        if { [info exists row($attr)] } {
            set varname attr_$attr

            # Convert the Tcl value to something we can use in the query
            switch $attr {
                short_name {
                    if { ![exists_and_not_null row(pretty_name)] } {
                        if { [empty_string_p $row(short_name)] } {
                            error "You cannot edit with an empty short_name without also setting pretty_name"
                        } else {
                            set row(pretty_name) {}
                        }
                    }
                        
                    set $varname [workflow::state::fsm::generate_short_name \
                                      -workflow_id $workflow_id \
                                      -pretty_name $row(pretty_name) \
                                      -short_name $row(short_name) \
                                      -state_id $state_id]
                }
                default {
                    set $varname $row($attr)
                }
            }

            # Add the column to the SET clause
            lappend set_clauses "$attr = :$varname"

            unset missing_elm($attr)
        }
    }

    db_transaction {
    
        # Update state
        if { [llength $set_clauses] > 0 } {
            db_dml update_action "
                update workflow_fsm_states
                set    [join $set_clauses ", "]
                where  state_id = :state_id
            "
        }

        # Check that there are no unknown attributes
        if { [llength [array names missing_elm]] > 0 } {
            error "Trying to set illegal state attributes: [join [array names missing_elm] ", "]"
        }

        if { !$internal_p } {
            workflow::definition_changed_handler -workflow_id $workflow_id
        }
    }

    if { !$internal_p } {
        workflow::flush_cache -workflow_id $workflow_id
    }

    return $state_id
}

ad_proc -private workflow::state::fsm::update_sort_order {
    {-workflow_id:required}
    {-sort_order:required}
} {
    Increase the sort_order of other states, if the new sort_order is already taken.
} { 
    set sort_order_taken_p [db_string select_sort_order_p {}]
    if { $sort_order_taken_p } {
        db_dml update_sort_order {}
    }
}

ad_proc -public workflow::state::fsm::get_existing_short_names {
    {-workflow_id:required}
    {-ignore_state_id {}}
} {
    Returns a list of existing state short_names in this workflow.
    Useful when you're trying to ensure a short_name is unique, 
    or construct a new short_name that is guaranteed to be unique.

    @param ignore_state_id   If specified, the short_name for the given state will not be included in the result set.
} {
    set result [list]

    foreach state_id [workflow::fsm::get_states -workflow_id $workflow_id] {
        if { [empty_string_p $ignore_state_id] || ![string equal $ignore_state_id $state_id] } {
            lappend result [workflow::state::fsm::get_element -state_id $state_id -element short_name]
        }
    }

    return $result
}

ad_proc -public workflow::state::fsm::generate_short_name {
    {-workflow_id:required}
    {-pretty_name:required}
    {-short_name {}}
    {-state_id {}}
} {
    Generate a unique short_name from pretty_name.
    
    @param state_id    If you pass in this, we will allow that state's short_name to be reused.
    
} {
    set existing_short_names [workflow::state::fsm::get_existing_short_names \
                                  -workflow_id $workflow_id \
                                  -ignore_state_id $state_id]
    
    if { [empty_string_p $short_name] } {
        if { [empty_string_p $pretty_name] } {
            error "Cannot have empty pretty_name when short_name is empty"
        }
        set short_name [util_text_to_url \
                            -replacement "_" \
                            -existing_urls $existing_short_names \
                            -text $pretty_name]
    } else {
        # Make lowercase, remove illegal characters
        set short_name [string tolower $short_name]
        regsub -all {[- ]} $short_name {_} short_name
        regsub -all {[^a-zA-Z_0-9]} $short_name {} short_name

        if { [lsearch -exact $existing_short_names $short_name] != -1 } {
            error "State with short_name '$short_name' already exists in this workflow."
        }
    }

    return $short_name
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

    set workflow_id [workflow::state::fsm::get_workflow_id -state_id $state_id]
    array set state_data [workflow::state::fsm::get_all_info -workflow_id $workflow_id]

    array set row $state_data($state_id)
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

    @param workflow_id The id of the workflow to get the states spec for

    @return The states spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # states(short_name) { ... state-spec ... }
    set states_list [list]
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
    util_memoize_flush [list workflow::state::fsm::get_all_info_not_cached -workflow_id $workflow_id]    
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
