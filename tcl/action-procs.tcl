ad_library {
    Procedures in the workflow::action namespace.
    
    @creation-date 9 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::action {}
namespace eval workflow:::action::fsm {}




#####
#
#  workflow::action namespace
#
#####

ad_proc -public workflow::action::new {
    {-workflow_id:required}
    {-sort_order {}}
    {-short_name:required}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-edit_fields {}}
    {-assigned_role {}}
    {-allowed_roles {}}
    {-privileges {}}
    {-callbacks {}}
    {-always_enabled_p f}
    {-initial_action_p f}
} {
    This procedure is normally not invoked from application code. Instead
    a procedure for a certain workflow implementation, such as for example
    workflow::fsm::action::new (for Finite State Machine workflows), is used.

    @param workflow_id            The id of the FSM workflow to add the action to
    @param sort_order             The number which this action should be in the sort ordering sequence. 
                                  Leave blank to add action at the end. If you provide a sort_order number
                                  which already exists, existing actions are pushed down one number.
    @param short_name             Short name of the action for use in source code.
                                  Should be on Tcl variable syntax.
    @param pretty_name            Human readable name of the action for use in UI.
    @param pretty_past_tense      Past tense of pretty name
    @param edit_fields            A space-separated list of the names of form fields which should be
                                  opened for editing when this action is carried out.
    @param assigned_role          The name of an assigned role. Users in this 
                                  role are expected (obliged) to take 
                                  the action.
    @param allowed_roles          A list of role names. Users in these roles are 
                                  allowed to take the action.
                                  
    @param privileges             Users with these privileges on the object 
                                  treated by the workflow (i.e. a bug in the 
                                  Bug Tracker) will be allowed to take this 
                                  action.
    @param callbacks           List of names of service contract implementations of callbacks for the action in 
                                  impl_owner_name.impl_name format.
    @param initial_action_p       Use this switch to indicate that this is the initial
                                  action that will fire whenever a case of the workflow
                                  is created. The initial action is used to determine
                                  the initial state of the worklow as well as any 
                                  procedures that should be executed when the case created.

    @return The id of the created action

    @see workflow::fsm::action::new

    @author Peter Marklund
} {
    db_transaction {
        # Insert basic action info
        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order \
                    -workflow_id $workflow_id \
                    -table_name "workflow_actions"]
        } else {
            set sort_order_taken_p [db_string select_sort_order_p {}]
            if { $sort_order_taken_p } {
                db_dml update_sort_order {}
            }
        }

        set action_id [db_nextval "workflow_actions_seq"]

        if { [empty_string_p $assigned_role] } {
            set assigned_role_id [db_null]
        } else {
            set assigned_role_id [workflow::role::get_id \
                    -workflow_id $workflow_id \
                    -short_name $assigned_role]
            if { [empty_string_p $assigned_role_id] } {
                error "Cannot find role '$assigned_role' to be the assigned role for action '$short_name'"
            }
        }

        # Insert the action
        db_dml insert_action {}

        # Record which roles are allowed to take action
        foreach allowed_role $allowed_roles {
            db_dml insert_allowed_role {}
        }

        # Record which privileges enable the action
        foreach privilege $privileges {
            db_dml insert_privilege {}
        }
        
        # Record if this is an initial action
        if { [string equal $initial_action_p "t"] } {
            db_dml insert_initial_action {}
        }

        # Callbacks
        foreach callback_name $callbacks {
            workflow::action::callback_insert \
                    -action_id $action_id \
                    -name $callback_name
        }

    }

    return $action_id
}

ad_proc -public workflow::action::get_assigned_role {
    {-action_id:required}
} {
    Return the assigned role of the given action
    @param action_id The action_id of the action.
    @return role_id of the assigned role.
} {
    return [db_string select_assigned_role {}]
}

ad_proc -public workflow::action::get_allowed_roles {
    {-action_id:required}
} {
    Return the assigned role of the given action
    @param action_id The action_id of the action.
    @return List of role_id of the allowed roles
} {
    return [db_list select_allowed_roles {}]
}

ad_proc -public workflow::action::get_privileges {
    {-action_id:required}
    {-no_admin:boolean}
} {
    Return the assigned role of the given action
    @param action_id The action_id of the action.
    @return List of privileges that give permission to do this action
} {
    set privileges [db_list select_privileges {}]

    # Admins always have privilege
    if { !$no_admin_p } {
        lappend privileges "admin"
    }

    return $privileges
}

ad_proc -public workflow::action::get_id {
    {-workflow_id:required}
    {-short_name:required}
} {
    Return the action_id of the action with the given short_name in the given workflow.

    @param workflow_id The ID of the workflow
    @param short_name The short_name of the action
    @return action_id of the desired action, or the empty string if it can't be found.
} {
    return [db_string select_action_id {} -default {}]
}

ad_proc -public workflow::action::get {
    {-action_id:required}
    {-array:required}
} {
    Return information about an action with a given id.

    @author Peter Marklund
    @author Lars Pind (lars@collaboraid.biz)

    @return An array list with workflow_id, sort_order, short_name, pretty_name, 
            pretty_past_tense, assigned_role, and always_enabled_p column 
            values for an action.
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    db_1row action_info {} -column_array row

    set row(callbacks) [db_list action_callbacks {}]
    set row(allowed_roles) [db_list action_allowed_roles {}]
    set row(privileges) [get_privileges -action_id $action_id -no_admin]
    
}

ad_proc -public workflow::action::get_element {
    {-action_id:required}
    {-element:required}
} {
    Return a single element from the information about a action.

    @param action_id The ID of the action
    @param element The element you want
    @return The element you asked for

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -action_id $action_id -array row
    return $row($element)
}

ad_proc -public workflow::action::callback_insert {
    {-action_id:required}
    {-name:required}
    {-sort_order {}}
} {
    Add a side-effect to an action.
    
    @param action_id The ID of the action.
    @param name Name of service contract implementation, in the form (impl_owner_name).(impl_name), 
    for example, bug-tracker.CaptureResolutionCode
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
    return $acs_sc_impl_id
}





#####
#
# workflow::action::fsm
#
#####

ad_proc -public workflow::action::fsm::new {
    {-workflow_id:required}
    {-sort_order {}}
    {-short_name:required}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-edit_fields {}}
    {-allowed_roles {}}
    {-assigned_role {}}
    {-privileges {}}
    {-enabled_states {}}
    {-new_state {}}
    {-callbacks {}}
    {-always_enabled_p f}
    {-initial_action_p f}
} {
    Add an action to a certain FSM (Finite State Machine) workflow. This procedure
    invokes the generic workflow::action::new procedures and does additional inserts
    for FSM specific information. See the parameter
    documentation for the proc workflow::action::new.

    @see workflow::action::new

    @author Peter Marklund
} {        

    db_transaction {
        # Generic workflow data:
        set action_id [workflow::action::new \
                -initial_action_p $initial_action_p \
                -workflow_id $workflow_id \
                -sort_order $sort_order \
                -short_name $short_name \
                -pretty_name $pretty_name \
                -pretty_past_tense $pretty_past_tense \
                -edit_fields $edit_fields \
                -allowed_roles $allowed_roles \
                -assigned_role $assigned_role \
                -privileges $privileges \
                -callbacks $callbacks \
                -always_enabled_p $always_enabled_p]

        # FSM specific data:

        # Record whether the action changes state
        if { ![empty_string_p $new_state] } {
            set new_state_id [workflow::state::fsm::get_id \
                    -workflow_id $workflow_id \
                    -short_name $new_state]
        } else {
            set new_state_id [db_null]
        }
        db_dml insert_fsm_action {}

        # Record in which states the action is enabled
        foreach state_short_name $enabled_states {
            set enabled_state_id [workflow::state::fsm::get_id \
                    -workflow_id $workflow_id \
                    -short_name $state_short_name]
            db_dml insert_enabled_state {}
        }
    }   
}

ad_proc -public workflow::action::fsm::get_new_state {
    {-action_id:required}
} {
    Return the new state for an action
    @param action_id The action_id of the action.
    @return The new state after executing this action, or the empty string if the action doesn't change the state.
} {
    return [db_string select_new_state {} -default {}]
}

ad_proc -public workflow::action::fsm::get {
    {-action_id:required}
    {-array:required}
} {
    Return information about an action with a given id, including
    FSM-related info such as 'enabled_states', and 'new_state'.

    @author Peter Marklund
    @author Lars Pind (lars@collaboraid.biz)
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row
    
    workflow::action::get -action_id $action_id -array row
    
    # Get new_state
    db_0or1row action_fsm_info {} -column_array additional_row
    array set row [array get additional_row]
    
    # Get enabled_states
    set row(enabled_states) [db_list action_enabled_short_name {}]

}

ad_proc -public workflow::action::fsm::get_element {
    {-action_id:required}
    {-element:required}
} {
    Return element from information about an action with a given id, including
    FSM-related info such as 'enabled_in_states', and 'new_state'.

    @author Peter Marklund
    @author Lars Pind (lars@collaboraid.biz)
} {
    workflow::action::fsm::get -action_id $action_id -array row
    return $row($element)
}

    

#####
# Private procs
#####

ad_proc -private workflow::action::fsm::parse_spec {
    {-workflow_id:required}
    {-short_name:required}
    {-spec:required}
} {
    Parse the spec for an individual action definition.

    @param workflow_id The id of the workflow to delete.
    @param short_name The short_name of the action
    @param spec The action spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # Initialize array with default values
    array set action { 
        pretty_past_tense {} 
        edit_fields {}
        allowed_roles {} 
        assigned_role {} 
        privileges {} 
        always_enabled_p f 
        enabled_states {} 
        new_state {} 
        initial_action_p f
        callbacks {}
    }
    
    # Get the info from the spec
    array set action $spec

    # Create the action
    set action_id [workflow::action::fsm::new \
            -workflow_id $workflow_id \
            -short_name $short_name \
            -pretty_name $action(pretty_name) \
            -pretty_past_tense $action(pretty_past_tense) \
            -edit_fields $action(edit_fields) \
            -allowed_roles $action(allowed_roles) \
            -assigned_role $action(assigned_role) \
            -privileges $action(privileges) \
            -always_enabled_p $action(always_enabled_p) \
            -enabled_states $action(enabled_states) \
            -new_state $action(new_state) \
            -callbacks $action(callbacks) \
            -initial_action_p $action(initial_action_p)
            ]
}

ad_proc -private workflow::action::fsm::parse_actions_spec {
    {-workflow_id:required}
    {-spec:required}
} {
    Parse the spec for the block containing the definition of all
    actions for the workflow.

    @param workflow_id The id of the workflow to delete.
    @param spec The actions spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    foreach { short_name subspec } $spec {
        workflow::action::fsm::parse_spec \
                -workflow_id $workflow_id \
                -short_name $short_name \
                -spec $subspec
    }
}

ad_proc -private workflow::action::fsm::generate_spec {
    {-action_id:required}
} {
    Generate the spec for an individual action definition.

    @param action_id The id of the action to generate spec for.
    @return spec The actions spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    get -action_id $action_id -array row

    set row(assigned_role) $row(assigned_role_short_name)
    
    # Get rid of elements that shouldn't go into the spec
    array unset row short_name 
    array unset row action_id
    array unset row workflow_id
    array unset row sort_order
    array unset row assigned_role_short_name
    
    # Get rid of a few defaults
    array set defaults { initial_action_p f always_enabled_p f }

    foreach name [array names defaults] {
        if { [string equal $row($name) $defaults($name)] } {
            array unset row $name
        }
    }

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
    
ad_proc -private workflow::action::fsm::generate_actions_spec {
    {-workflow_id:required}
} {
    Generate the spec for the block containing the definition of all
    actions for the workflow.

    @param workflow_id The id of the workflow to delete.
    @return The actions spec

    @author Lars Pind (lars@collaboraid.biz)
} {
    # actions(short_name) { ... action-spec ... }
    set actions [list]

    foreach action_id [workflow::get_actions -workflow_id $workflow_id] {
        lappend actions [get_element -action_id $action_id -element short_name] [generate_spec -action_id $action_id]
    }
    
    return $actions
}
