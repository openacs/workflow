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
    {-package_key {}}
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

        if { [empty_string_p $package_key] } {
            set package_key [db_null]
        }

        if { [empty_string_p $object_id] } {
            set object_id [db_null]
        }

        # Insert the workflow
        set workflow_id [db_string do_insert {}]
        
        # Callbacks
        foreach callback_name $callbacks {
            workflow::callback_insert \
                    -workflow_id $workflow_id \
                    -name $callback_name
        }
        
        # May need to parse the simple workflow notation
        if { [exists_and_not_null workflow] } {
            parse_spec -workflow_id $workflow_id -spec $workflow
        }
    }

    return $workflow_id
}

ad_proc -private workflow::fsm::parse_spec {
    {-workflow_id:required}
    {-spec:required}
} {
    Parse the -workflow argument to workflow::new and create roles,
    states, actions, etc., as appropriate

    @param workflow_id The id of the workflow to delete.

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    array set workflow { roles {} states {} actions {} }
    array set workflow $spec
    
    workflow::roles::parse_spec $workflow(roles)
    workflow::roles::parse_spec $workflow(roles)
}



ad_proc -public workflow::delete {
    {-workflow_id:required}
} {
    Delete a generic workflow and all data attached to it (states, actions etc.).

    @param workflow_id The id of the workflow to delete.

    @author Peter Marklund
} {
    return [db_string do_delete {}]
}

ad_proc -public workflow::get_id {
    {-package_key {}}
    {-object_id {}}
    {-short_name:required}
} {
    Get workflow_id by short_name and object_id.
    
    @param object_id The ID of the object the workflow's for (typically a package instance)
    @param short_name the short name of the workflow you want

    @author Lars Pind (lars@collaboraid.biz)
} {
    if { [empty_string_p $package_key] } {
        if { [empty_string_p $object_id] } {
            if { [ad_conn isconnected] } {
                set package_key [ad_conn package_key]
            } else {
                error "You must supply either package_key or object_id, or there must be a current connection"
                set query_name select_workflow_id_by_package_key
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

    set workflow_id [db_string $query_name {} -default {}]
    if { ![empty_string_p $workflow_id] } {
        return $workflow_id
    } else {
        error "No workflow found with object_id $object_id and short_name $short_name"
    }
}

ad_proc -public workflow::get_initial_action {
    {-workflow_id:required}
} {
    Get the action_id of the special 'open' action of a workflow.
    
    @param workflow_id The ID of the workflow
    @return action_id of the magic 'open' action

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_initial_action {}]
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
    # TODO:
    # Insert for real when the service contracts have been defined
    
    ns_log Error "LARS: workflow::callback_insert -- would have inserted the callback $name to workflow $workflow_id"
    return

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
    return $acs_sc_impl_id
}



#####
#
# workflow::fsm namespace
#
#####

ad_proc -public workflow::fsm::new {
    {-short_name:required}
    {-pretty_name:required}
    {-object_id:required}
    {-object_type "acs_object"}
    {-callbacks {}}
    {-spec}
} {
    Creates a new FSM workflow, with an optional spec argument.

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

    db_transaction {

        # Create the workflow
        set workflow_id [workflow::new \
                -short_name $short_name \
                -pretty_name $pretty_name \
                -object_id $object_id \
                -object_type $object_type \
                -callbacks $callbacks]
        
        # May need to parse the simple workflow notation
        if { [exists_and_not_null spec] } {
            parse_spec -workflow_id $workflow_id -spec $spec
        }
    }

    return $workflow_id
}

ad_proc -private workflow::fsm::parse_spec {
    {-workflow_id:required}
    {-spec:required}
} {
    Parse the -workflow argument to workflow::new and create roles,
    states, actions, etc., as appropriate

    @param workflow_id The id of the workflow to delete.
    @param spec The roles spec

    @author Lars Pind (lars@collaboraid.biz)
    @see workflow::new
} {
    array set workflow { roles {} states {} actions {} }
    array set workflow $spec
    
    workflow::role::parse_roles_spec \
            -workflow_id $workflow_id \
            -spec $workflow(roles)

    workflow::state::fsm::parse_states_spec \
            -workflow_id $workflow_id \
            -spec $workflow(states)

    workflow::action::fsm::parse_actions_spec \
            -workflow_id $workflow_id \
            -spec $workflow(actions)
}







#####
#
#  workflow::service_contract
#
#####

ad_proc -public workflow::service_contract::role_default_assignee {} {
    return "Role_DefaultAssignees"
}

ad_proc -public workflow::service_contract::role_assignee_pick_list {} {
    return "Role_AssigneePickList"
}

ad_proc -public workflow::service_contract::role_assignee_subquery {} {
    return "Role_AssigneeSubQuery"
}

ad_proc -public workflow::service_contract::action_side_effect {} {
    return "Action_SideEffect"
}

ad_proc -public workflow::service_contract::activity_log_format_title {} {
    return "ActivityLog_FormatTitle"
}

ad_proc -public workflow::service_contract::get_impl_id {
    {-name:required}
} {
    set namev [split $name "."]

    set impl_owner_name [lindex $namev 0]
    set impl_name [lindex $namev 1]

    set acs_sc_impl_id [db_string select_impl_id {}]

    return $acs_sc_impl_id
}
