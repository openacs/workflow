ad_library {
    Procedures in the workflow namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow {}
namespace eval workflow::fsm {}
namespace eval workflow::service_contract {}

#####
#
#  workflow namespace
#
#####

ad_proc -public workflow::package_key {} {
    return "workflow"
}

ad_proc -public workflow::new {
    {-short_name:required}
    {-pretty_name:required}
    {-package_key:required}
    {-object_id {}}
    {-object_type "acs_object"}
    {-callbacks {}}
} {
    Creates a new workflow. For each workflow you must create an initial action
    (using the workflow::action::new proc) to be fired when a workflow case is opened.

    @param short_name  For referring to the workflow from Tcl code. Use Tcl variable syntax.
    @param pretty_name A human readable name for the workflow for use in the UI.
    @param package_key The package to which this workflow belongs
    @param object_id   The id of an ACS Object indicating the scope the workflow. 
                       Typically this will be the id of a package type or a package instance
                       but it could also be some other type of ACS object within a package, for example
                       the id of a bug in the Bug Tracker application.
    @param object_type The type of objects that the workflow will be applied to. Valid values are in the
                       acs_object_types table. The parameter is optional and defaults to acs_object.
    @param callbacks List of names of service contract implementations of callbacks for the workflow in 
                       impl_owner_name.impl_name format.
    @return           New workflow_id.

    @author Peter Marklund
} {
    # Auditing information for the acs_objects table
    if { [ad_conn isconnected] } {            
        set creation_user [ad_conn user_id]
        set creation_ip [ad_conn peeraddr]        
    } else {
        # No HTTP request so we have don't have IP and user info
        set creation_user {}
        set creation_ip {}
    }

    # It makes sense that the workflow inherits permissions from the object 
    # (typically package type or package instance) that sets the scope of the workflow
    set context_id $object_id

    db_transaction {

        if { [empty_string_p $object_id] } {
            set object_id [db_null]
        }

        # Insert the workflow
        set workflow_id [db_exec_plsql do_insert {}]
        
        # Callbacks
        foreach callback_name $callbacks {
            ns_log Notice "callback_name = $callback_name"
            workflow::callback_insert \
                    -workflow_id $workflow_id \
                    -name $callback_name
        }
        
        # May need to parse the simple workflow notation
        if { [exists_and_not_null workflow] } {
            parse_spec -workflow_id $workflow_id -spec $workflow
        }
    }

    # The lookup proc might have cached that there is no workflow
    # with the short name of the workflow we have now created so
    # we need to flush
    util_memoize_flush_regexp {^workflow::get_id_not_cached}    

    return $workflow_id
}

ad_proc -public workflow::exists_p {
    {-workflow_id:required}
} {
    Return 1 if the workflow with given id exists and 0 otherwise.
    This proc is currently not cached.
} {
    return [db_string do_select {}
}

ad_proc -public workflow::delete {
    {-workflow_id:required}
} {
    Delete a generic workflow and all data attached to it (states, actions etc.).

    @param workflow_id The id of the workflow to delete.

    @author Peter Marklund
} {
    workflow::flush_cache -workflow_id $workflow_id

    return [db_exec_plsql do_delete {}]
}

ad_proc -public workflow::get_id {
    {-package_key {}}
    {-object_id {}}
    {-short_name:required}
} {
    Get workflow_id by short_name and object_id. Provide either package_key
    or object_id.
    
    @param object_id The ID of the object the workflow's for (typically a package instance)
    @param package_key The key of the package workflow belongs to.
    @param short_name the short name of the workflow you want

    @return The id of the workflow or the empty string if no workflow was found.

    @author Lars Pind (lars@collaboraid.biz)
} {
    set workflow_id [util_memoize [list workflow::get_id_not_cached \
                                       -package_key $package_key \
                                       -object_id $object_id \
                                       -short_name $short_name] [workflow::cache_timeout]]

    return $workflow_id
}

ad_proc -public workflow::get {
    {-workflow_id:required}
    {-array:required}
} {
    Return information about a workflow. Uses util_memoize
    to cache values from the database.

    @author Lars Pind (lars@collaboraid.biz)

    @param workflow_id ID of workflow
    @param array name of array in which the info will be returned
    @return An array list with keys workflow_id, short_name,
            pretty_name, object_id, package_key, object_type, initial_action,
            and callbacks.

} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    array set row \
            [util_memoize [list workflow::get_not_cached -workflow_id $workflow_id] [workflow::cache_timeout]]
}

ad_proc -public workflow::get_element {
    {-workflow_id:required}
    {-element:required}
} {
    Return a single element from the information about a workflow.

    @param workflow_id The ID of the workflow
    @return The element you asked for

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -workflow_id $workflow_id -array row
    return $row($element)
}

ad_proc -public workflow::get_roles {
    {-workflow_id:required}
} {
    Get the role_id's of all the roles in the workflow.
    
    @param workflow_id The ID of the workflow
    @return list of role_id's.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Use cached data about roles
    array set role_data [workflow::role::get_all_info -workflow_id $workflow_id]

    return $role_data(role_ids)
}

ad_proc -public workflow::get_actions {
    {-workflow_id:required}
} {
    Get the action_id's of all the actions in the workflow.
    
    @param workflow_id The ID of the workflow
    @return list of action_id's.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Use cached data about actions
    array set action_data [workflow::action::get_all_info -workflow_id $workflow_id]

    return $action_data(action_ids)
}





#####
# Private procs
#####



ad_proc -private workflow::flush_cache {
    {-workflow_id:required}
} {
    Flush all cached data related to the given
    workflow instance.
} {
    # The workflow instance that we are flushing may be in the get_id lookup
    # cache so we have to flush it
    util_memoize_flush_regexp {^workflow::get_id_not_cached}

    # Flush workflow scalar attributes and workflow callbacks
    util_memoize_flush [list workflow::get_not_cached -workflow_id $workflow_id]

    # Delegating flushing of info related to roles, actions, and states
    workflow::role::flush_cache -workflow_id $workflow_id
    workflow::action::flush_cache -workflow_id $workflow_id
    workflow::state::flush_cache -workflow_id $workflow_id

    # Flush all workflow cases from the cache. We are flushing more than needed here
    # but this approach seems easier and faster than looping over a potentially big number
    # of cases mapped to the workflow in the database, only a few of which may actually be 
    # cached and need flushing
    workflow::case::flush_cache
}

ad_proc -private workflow::cache_timeout {} {
    Returns the timeout to give to util_memoize (max_age parameter)
    for all workflow level data. Should probably
    be an APM parameter.

    @author Peter Marklund
} {
    return ""
}

ad_proc -private workflow::get_id_not_cached {
    {-package_key {}}
    {-object_id {}}
    {-short_name:required}
} {
    Private proc not to be used by applications, use workflow::get_id
    instead.
} {
    if { [empty_string_p $package_key] } {
        if { [empty_string_p $object_id] } {
            if { [ad_conn isconnected] } {
                set package_key [ad_conn package_key]
                set query_name select_workflow_id_by_package_key
            } else {
                error "You must supply either package_key or object_id, or there must be a current connection"
            }
        } else {
            set query_name select_workflow_id_by_object_id
        }
    } else {
        if { [empty_string_p $object_id] } {
            set query_name select_workflow_id_by_package_key
        } else {
            error "You must supply only one of either package_key or object_id"
        }
    }

    return [db_string $query_name {} -default {}]
}

ad_proc -private workflow::get_not_cached {
    {-workflow_id:required}
} {
    Private procedure that should never be used by application code - use
    workflow::get instead.
    Returns info about the workflow in an array list. Always
    goes to the database.

    @see workflow::get

    @author Peter Marklund
} {
    db_1row workflow_info {} -column_array row

    set callbacks [list]
    set callback_ids [list]
    array set callback_impl_names [list]
    array set callbacks_array [list]

    db_foreach workflow_callbacks {} -column_array callback_row {
        lappend callbacks "$callback_row(impl_owner_name).$callback_row(impl_name)"
        lappend callback_ids $callback_row(impl_id)
        lappend callback_impl_names($callback_row(contract_name)) $callback_row(impl_name)
        set callbacks_array($callback_row(impl_id)) [array get callback_row]
    } 

    set row(callbacks) $callbacks
    set row(callback_ids) $callback_ids
    set row(callback_impl_names) [array get callback_impl_names]
    set row(callbacks_array) [array get callbacks_array]

    return [array get row]
}

ad_proc -private workflow::default_sort_order {
    {-workflow_id:required}
    {-table_name:required}
} {
    By default the sort_order will be the highest current sort order plus 1.
    This reflects the order in which states and actions are added to the 
    workflow starting with 1
    
    @author Peter Marklund
} {
    set max_sort_order [db_string max_sort_order {} -default 0]

    return [expr $max_sort_order + 1]
}

ad_proc -private workflow::callback_insert {
    {-workflow_id:required}
    {-name:required}
    {-sort_order {}}
} {
    Add a side-effect to a workflow.
    
    @param workflow_id The ID of the workflow.
    @param name Name of service contract implementation, in the form (impl_owner_name).(impl_name), 
    for example, bug-tracker.FormatLogTitle.
    @param sort_order The sort_order for the rule. Leave blank to add to the end of the list
    
    @author Lars Pind (lars@collaboraid.biz)
} {
    db_transaction {

        # Get the impl_id
        set acs_sc_impl_id [workflow::service_contract::get_impl_id -name $name]

        # Get the sort order
        if { ![exists_and_not_null sort_order] } {
            set sort_order [db_string select_sort_order {}]
        }

        # Insert the callback
        db_dml insert_callback {}
    }

    # Flush workflow scalar attributes and workflow callbacks
    util_memoize_flush [list workflow::get_not_cached -workflow_id $workflow_id]

    return $acs_sc_impl_id
}

ad_proc -private workflow::get_callbacks {
    {-workflow_id:required}
    {-contract_name:required}
} {
    Return the implementation names for a certain contract and a 
    given workflow.

    @author Peter Marklund
} {
    array set callback_impl_names [workflow::get_element -workflow_id $workflow_id -element callback_impl_names]

    if { [info exists callback_impl_names($contract_name)] } {
        return $callback_impl_names($contract_name)
    } else {
        return {}
    }
}

ad_proc -public workflow::get_notification_links {
    {-workflow_id:required}
    {-case_id}
    {-return_url}
} {
    Return a links to sign up for notifications.
    @return A multirow with columns url, label, title
} {
    
}


#####
#
# workflow::fsm namespace
#
#####

ad_proc -public workflow::fsm::new_from_spec {
    {-package_key {}}
    {-object_id {}}
    {-spec:required}
} {
    Create a new workflow from spec

    @param workflow_id The id of the workflow to delete.
    @param spec The roles spec
    @return A list of IDs of the workflows created

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    if { [llength $spec] != 2 } {
        error "You can only create one workflow at a time"
    }

    db_transaction {
        foreach { short_name spec } $spec {
            set workflow_id [workflow::fsm::parse_spec \
                    -package_key $package_key \
                    -object_id $object_id \
                    -short_name $short_name \
                    -spec $spec]
        }
    }

    # The lookup proc might have cached that there is no workflow
    # with the short name of the workflow we have now created so
    # we need to flush
    util_memoize_flush_regexp {^workflow::get_id_not_cached}    

    return $workflow_id
}

ad_proc -public workflow::fsm::clone {
    {-workflow_id:required}
    {-package_key {}}
    {-object_id {}}
} {
    Clones an existing FSM workflow

    @param short_name  For referring to the workflow from Tcl code. Use Tcl variable syntax.
    @param pretty_name A human readable name for the workflow for use in the UI.
    @param object_id   The id of an ACS Object indicating the scope the workflow. 
                       Typically this will be the id of a package type or a package instance
                       but it could also be some other type of ACS object within a package, for example
                       the id of a bug in the Bug Tracker application.
    @param object_type The type of objects that the workflow will be applied to. Valid values are in the
                       acs_object_types table. The parameter is optional and defaults to acs_object.
    @param spec        The workflow spec in array-lists-in-array-lists format. 

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    set workflow_id [new_from_spec \
            -package_key $package_key \
            -object_id $object_id \
            -spec [generate_spec -workflow_id $workflow_id] \
            ]

    return $workflow_id
}

ad_proc -public workflow::fsm::generate_spec {
    {-workflow_id:required}
} {
    Generate a spec for a workflow in array list style.
    
    @param workflow_id The id of the workflow to delete.
    @return The spec for the workflow.

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    workflow::get -workflow_id $workflow_id -array row

    set short_name $row(short_name)

    array unset row object_id
    array unset row workflow_id
    array unset row short_name
    array unset row callbacks_array
    array unset row callback_ids
    array unset row callback_impl_names
    array unset row initial_action
    array unset row initial_action_id

    set spec [list]

    # Get rid of empty strings
    foreach name [array names row] {
        if { [empty_string_p $row($name)] } {
            array unset row $name
        }
    }

    foreach name [lsort [array names row]] {
        lappend spec $name $row($name)
    }

    lappend spec roles [workflow::role::generate_roles_spec -workflow_id $workflow_id]
    lappend spec states [workflow::state::fsm::generate_states_spec -workflow_id $workflow_id]
    lappend spec actions [workflow::action::fsm::generate_actions_spec -workflow_id $workflow_id]
    
    return [list $short_name $spec]
}

ad_proc -public workflow::fsm::get_states {
    {-workflow_id:required}
} {
    Get the state_id's of all the states in the workflow. 
    
    @param workflow_id The ID of the workflow
    @return list of state_id's.

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Use cached data
    array set state_data [workflow::state::fsm::get_all_info -workflow_id $workflow_id]

    return $state_data(state_ids)
}

ad_proc -public workflow::fsm::get_initial_state {
    {-workflow_id:required}
} {
    Get the id of the state that a workflow case is in once it's
    started (after the initial action is fired).

    @author Peter Marklund
} {
    set initial_action_id [workflow::get_element \
            -workflow_id $workflow_id \
            -element initial_action_id]

    set initial_state [workflow::action::fsm::get_element \
            -action_id $initial_action_id \
            -element new_state_id]

    return $initial_state
}

#####
# Private procs
#####

ad_proc -private workflow::fsm::parse_spec {
    {-short_name:required}
    {-package_key {}}
    {-object_id {}}
    {-spec:required}
} {
    Create workflow, roles, states, actions, etc., as appropriate

    @param workflow_id The id of the workflow to delete.
    @param spec The roles spec

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    # Default values
    array set workflow { 
        roles {} 
        states {} 
        actions {} 
        callbacks {}
        object_type {acs_object}
    }

    array set workflow $spec

    # Override stuff in the spec with stuff provided as an argument here
    foreach var { package_key object_id } {
        if { ![empty_string_p [set $var]] } {
            set workflow($var) [set $var]
        }
    }
    
    set workflow_id [workflow::new \
            -short_name $short_name \
            -pretty_name $workflow(pretty_name) \
            -package_key $workflow(package_key) \
            -object_id $object_id \
            -object_type $workflow(object_type) \
            -callbacks $workflow(callbacks)]
    
    workflow::role::parse_roles_spec \
            -workflow_id $workflow_id \
            -spec $workflow(roles)

    workflow::state::fsm::parse_states_spec \
            -workflow_id $workflow_id \
            -spec $workflow(states)

    workflow::action::fsm::parse_actions_spec \
            -workflow_id $workflow_id \
            -spec $workflow(actions)
    
    return $workflow_id
}









#####
#
#  workflow::service_contract
#
#####

ad_proc -public workflow::service_contract::role_default_assignees {} {
    return "[workflow::package_key].Role_DefaultAssignees"
}

ad_proc -public workflow::service_contract::role_assignee_pick_list {} {
    return "[workflow::package_key].Role_AssigneePickList"
}

ad_proc -public workflow::service_contract::role_assignee_subquery {} {
    return "[workflow::package_key].Role_AssigneeSubQuery"
}

ad_proc -public workflow::service_contract::action_side_effect {} {
    return "[workflow::package_key].Action_SideEffect"
}

ad_proc -public workflow::service_contract::activity_log_format_title {} {
    return "[workflow::package_key].ActivityLog_FormatTitle"
}

ad_proc -public workflow::service_contract::notification_info {} {
    return "[workflow::package_key].NotificationInfo"
}

ad_proc -public workflow::service_contract::get_impl_id {
    {-name:required}
} {
    set namev [split $name "."]

    return [acs_sc::impl::get_id -owner [lindex $namev 0] -name [lindex $namev 1]]
}
