ad_library {
    Procedures in the workflow namespace.
    
    @creation-date 8 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow {}
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
    {-object_id:required}
    {-object_type "acs_object"}
} {
    Creates a new workflow. For each workflow you must create an initial action
    (using the workflow::action::new proc) to be fired when a workflow case is opened.

    @param short_name  For referring to the workflow from Tcl code. Use Tcl variable syntax.
    @param pretty_name A human readable name for the workflow for use in the UI.
    @param object_id   The id of an ACS Object indicating the scope the workflow. 
                       Typically this will be the id of a package type or a package instance
                       but it could also be some other type of ACS object within a package, for example
                       the id of a bug in the Bug Tracker application.
    @param object_type The type of objects that the workflow will be applied to. Valid values are in the
                       acs_object_types table. The parameter is optional and defaults to acs_object.

    @author Peter Marklund
} {
    # Auditing information for the acs_objects table
    if { [ad_conn isconnected] } {            
        set creation_user [ad_conn user_id]
        set creation_ip [ad_conn peeraddr]        
    } else {
        # No HTTP request so we have don't have IP and user info
        set creation_user ""
        set creation_ip ""
    }

    # It makes sense that the workflow inherits permissions from the object 
    # (typically package type or package instance) that sets the scope of the workflow
    set context_id $object_id

    # Insert the workflow
    set workflow_id [db_string do_insert {}]

    return $workflow_id
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
    {-object_id:required}
    {-short_name:required}
} {
    Get workflow_id by short_name and object_id.
    
    @param object_id The ID of the object the workflow's for (typically a package instance)
    @param short_name the short name of the workflow you want

    @author Lars Pind (lars@collaboraid.biz)
} {
    return [db_string select_workflow_id {} -default {}]
}

ad_proc -public workflow::action::get_initial_action {
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
    table_name
} {
    By default the sort_order will be the highest current sort order plus 1.
    This reflects the order in which states and actions are added to the 
    workflow starting with 1
    
    @author Peter Marklund
} {
    set sort_order_current \
            [db_string max_sort_order "select max(sort_order) \
                                       from $table_name \
                                       where workflow_id = $workflow_id" \
            -default 0]

    set sort_order [expr $sort_order_current + 1]

    return $sort_order
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

