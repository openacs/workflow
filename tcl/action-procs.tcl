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
    {-action_id {}}
    {-sort_order {}}
    {-short_name {}}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-edit_fields {}}
    {-assigned_role {}}
    {-allowed_roles {}}
    {-privileges {}}
    {-callbacks {}}
    {-always_enabled_p f}
    {-initial_action_p f}
    {-description {}}
    {-description_mime_type {}}
    {-timeout_seconds {}}
    {-internal:boolean}
} {
    This procedure is normally not invoked from application code. Instead
    a procedure for a certain workflow implementation, such as for example
    workflow::action::fsm::new (for Finite State Machine workflows), is used.

    @param workflow_id            The id of the FSM workflow to add the action to

    @param action_id              Optionally specify the ID of the new action.

    @param sort_order             The number which this action should be in the sort ordering sequence. 
                                  Leave blank to add action at the end. If you provide a sort_order number
                                  which already exists, existing actions are pushed down one number.

    @param short_name             Short name of the action for use in source code.
                                  Should be on Tcl variable syntax.

    @param pretty_name            Human readable name of the action for use in UI.

    @param pretty_past_tense      Past tense of pretty name

    @param edit_fields            A space-separated list of the names of form fields which should be
                                  opened for editing when this action is carried out.

    @param assigned_role          The short_name of an assigned role. Users in this 
                                  role are expected (obliged) to take 
                                  the action.

    @param allowed_roles          A list of role short_names or IDs. Users in these roles are 
                                  allowed to take the action.
                                  
    @param privileges             Users with these privileges on the object 
                                  treated by the workflow (i.e. a bug in the 
                                  Bug Tracker) will be allowed to take this 
                                  action.

    @param callbacks              List of names of service contract implementations of callbacks for the action in 
                                  impl_owner_name.impl_name format.

    @param initial_action_p       Use this switch to indicate that this is the initial
                                  action that will fire whenever a case of the workflow
                                  is created. The initial action is used to determine
                                  the initial state of the worklow as well as any 
                                  procedures that should be executed when the case created.

    @param timeout_seconds        If zero, the action will automatically fire whenever it becomes enabled.
                                  If greater than zero, the action will automatically fire x number of
                                  seconds after the action is enabled. If empty, will never fire automatically.

    @param internal               Set this flag if you're calling this proc from within the corresponding proc 
                                  for a particular workflow model. Will cause this proc to not flush the cache 
                                  or call workflow::definition_changed_handler, which the caller must then do.

    @return The id of the created action

    @see workflow::action::fsm::new
    @see workflow::definition_changed_handler

    @author Peter Marklund
} {
    db_transaction {
        # Insert basic action info
        if { [empty_string_p $sort_order] } {
            set sort_order [workflow::default_sort_order \
                    -workflow_id $workflow_id \
                    -table_name "workflow_actions"]
        } else {
            workflow::action::update_sort_order \
                -workflow_id $workflow_id \
                -sort_order $sort_order
        }

        set short_name [workflow::action::generate_short_name \
                            -workflow_id $workflow_id \
                            -pretty_name $pretty_name \
                            -short_name $short_name]

        if { [empty_string_p $action_id] } {
            set action_id [db_nextval "workflow_actions_seq"]
        }

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

        # Set all the other attributes
        array set update_cols [list]
        set update_cols(allowed_roles) $allowed_roles
        set update_cols(privileges) $privileges
        set update_cols(callbacks) $callbacks
        set update_cols(initial_action_p) $initial_action_p
        
        workflow::action::edit \
            -internal \
            -action_id $action_id \
            -workflow_id $workflow_id \
            -array update_cols

        if { !$internal_p } {
            workflow::definition_changed_handler -workflow_id $workflow_id
        }
    }

    if { !$internal_p } {
        # Flush the workflow cache, as changing an action changes the entire workflow
        # e.g. initial_action_p, enabled_in_states.
        workflow::flush_cache -workflow_id $workflow_id
    }
    
    return $action_id
}

ad_proc -public workflow::action::edit {
    {-action_id:required}
    {-workflow_id {}}
    {-array:required}
    {-internal:boolean}
} {
    Edit an action. 

    @param action_id    The action to edit.

    @param workflow_id  Optionally specify the workflow_id. If not specified, we will execute a query to find it.
    
    @param array        Name of an array in the caller's namespace with attributes to edit.

    @param internal     Set this flag if you're calling this proc from within the corresponding proc 
                        for a particular workflow model. Will cause this proc to not flush the cache 
                        or call workflow::definition_changed_handler, which the caller must then do.

    @return action_id
    
    @see workflow::action::new
} {
    upvar 1 $array row
    if { ![array exists row] } {
        error "Array $array does not exist or is not an array"
    }
    foreach name [array names row] {
        set missing_elm($name) 1
    }

    if { [empty_string_p $workflow_id] } {
        set workflow_id [workflow::action::get_element \
                             -action_id $action_id \
                             -element workflow_id]
    }

    set set_clauses [list]

    # Handle columns in the workflow_actions table
    foreach attr { 
        short_name pretty_name pretty_past_tense edit_fields description description_mime_type sort_order
        always_enabled_p 
        assigned_role
        timeout_seconds
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
                        
                    set $varname [workflow::action::generate_short_name \
                                      -workflow_id $workflow_id \
                                      -pretty_name $row(pretty_name) \
                                      -short_name $row(short_name)]
                }
                always_enabled_p {
                    set $varname [db_boolean [template::util::is_true $row($attr)]]
                }
                assigned_role {
                    if { [empty_string_p $row($attr)] } {
                        set $varname [db_null]
                    } else {
                        # Get role_id by short_name
                        set $varname [workflow::role::get_id \
                                          -workflow_id $workflow_id \
                                          -short_name $row($attr)]
                    }
                }
                default {
                    set $varname $row($attr)
                }
            }
            # Add the column to the SET clause
            switch $attr {
                timeout_seconds {
                    lappend set_clauses [db_map update_timeout_seconds]
                }
                default {
                    lappend set_clauses "$attr = :$varname"
                }
            }
            unset missing_elm($attr)
        }
    }
    
    db_transaction {
        if { [info exists row(sort_order)] } {
            workflow::action::update_sort_order \
                -workflow_id $workflow_id \
                -sort_order $row(sort_order)
        }
        
        # Update action
        if { [llength $set_clauses] > 0 } {
            db_dml update_action "
                update workflow_actions
                set    [join $set_clauses ", "]
                where  action_id = :action_id
            "
        }
        
        # Record which roles are allowed to take action
        if { [info exists row(allowed_roles)] } {
            db_dml delete_allowed_roles {
                delete from workflow_action_allowed_roles
                where  action_id = :action_id
            }
            foreach allowed_role $row(allowed_roles) {
                db_dml insert_allowed_role {}
            }
            unset missing_elm(allowed_roles)
        }
        
        # Record which privileges enable the action
        if { [info exists row(privileges)] } {
            db_dml delete_privileges {
                delete from workflow_action_privileges
                where  action_id = :action_id
            }
            foreach privilege $row(privileges) {
                db_dml insert_privilege {}
            }
            unset missing_elm(privileges)
        }
             
        # Record if this is an initial action
        if { [info exists row(initial_action_p)] } {
            if { [template::util::is_true $row(initial_action_p)] } {
                db_dml delete_initial_action {
                    delete from workflow_initial_action
                    where  workflow_id = :workflow_id
                }
                db_dml insert_initial_action {}
            }
            unset missing_elm(initial_action_p)
        }

        # Callbacks
        if { [info exists row(callbacks)] } {
            db_dml delete_callbacks {
                delete from workflow_action_callbacks
                where  action_id = :action_id
            }
            foreach callback_name $row(callbacks) {
                workflow::action::callback_insert \
                    -action_id $action_id \
                    -name $callback_name
            }
            unset missing_elm(callbacks)
        }

        # Check that there are no unknown attributes
        if { [llength [array names missing_elm]] > 0 } {
            error "Trying to set illegal action attributes: [join [array names missing_elm] ", "]"
        }

        if { !$internal_p } {
            workflow::definition_changed_handler -workflow_id $workflow_id
        }
    }

    if { !$internal_p } {
        # Flush the workflow cache, as changing an action changes the entire workflow
        # e.g. initial_action_p, enabled_in_states.
        workflow::flush_cache -workflow_id $workflow_id
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
    return [get_from_request_cache $action_id "assigned_role"]
}

ad_proc -public workflow::action::get_allowed_roles {
    {-action_id:required}
} {
    Return the allowed roles of the given action
    @param action_id The action_id of the action.
    @return List of role_id of the allowed roles
} {
    return [get_from_request_cache $action_id "allowed_role_ids"]
}

ad_proc -public workflow::action::get_privileges {
    {-action_id:required}
} {
    Return the assigned role of the given action
    @param action_id The action_id of the action.
    @return List of privileges that give permission to do this action
} {
    return [get_from_request_cache $action_id "privileges"]
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
    workflow::action::refresh_request_cache $workflow_id
    global __workflow_action_data,${workflow_id}

    foreach action_id [set __workflow_action_data,${workflow_id}(action_ids)] {
        array set one_action [set __workflow_action_data,${workflow_id}($action_id)]
        
        if { [string equal $one_action(short_name) $short_name] } {
            return $action_id
        }
    }

    error "workflow::action::get_id role with short_name $short_name not found for workflow $workflow_id"
}

ad_proc -public workflow::action::get_workflow_id {
    {-action_id:required}
} {
    Lookup the workflow_id of a certain action_id.

    @author Peter Marklund
} {
    return [util_memoize \
            [list workflow::action::get_workflow_id_not_cached -action_id $action_id]]
}

ad_proc -private workflow::action::get_workflow_id_not_cached {
    {-action_id:required}
} {
    This is a proc that should only be used internally by the workflow
    API, applications should use workflow::action::get_workflow_id instead.

    @author Peter Marklund
} {
    return [db_string select_workflow_id {}]
}

ad_proc -public workflow::action::get {
    {-action_id:required}
    {-array:required}
} {
    Return information about an action with a given id.

    @author Peter Marklund
    @author Lars Pind (lars@collaboraid.biz)

    @return The array will contain the following entries: 
            workflow_id, sort_order, short_name, pretty_name, 
            pretty_past_tense, assigned_role (short_name), assigned_role_id, 
            always_enabled_p, initial_action_p, description, 
            description_mime_type column values for an action.

    @see workflow::action::get_all_info
    @see workflow::action::get_all_info_not_cached
} {
    # Select the info into the upvar'ed Tcl Array
    upvar $array row

    array set row [get_from_request_cache $action_id]
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

    set workflow_id [workflow::action::get_workflow_id -action_id $action_id]
    workflow::action::flush_cache -workflow_id $workflow_id

    return $acs_sc_impl_id
}

ad_proc -private workflow::action::get_callbacks {
    {-action_id:required}
    {-contract_name:required}
} {
    Return a list of implementation names for the callbacks of a given workflow action.

    @see workflow::case::role::get_callbacks

    @author Peter Marklund
} {
    array set callbacks [get_from_request_cache $action_id callbacks_array]
    set callback_ids [get_from_request_cache $action_id callback_ids]
    
    # Loop over the callbacks and return the impl_names of those with a matching
    # contract name
    set impl_names [list]
    foreach callback_id $callback_ids {
        array set one_callback $callbacks($callback_id)

        if { [string equal $one_callback(contract_name) $contract_name] } {
            lappend impl_names $one_callback(impl_name)            
        }
    }

    return $impl_names
}

ad_proc -private workflow::action::update_sort_order {
    {-workflow_id:required}
    {-sort_order:required}
} {
    Increase the sort_order of other actions, if the new sort_order is already taken.
} { 
    set sort_order_taken_p [db_string select_sort_order_p {}]
    if { $sort_order_taken_p } {
        db_dml update_sort_order {}
    }
}

ad_proc -public workflow::action::get_existing_short_names {
    {-workflow_id:required}
    {-ignore_action_id {}}
} {
    Returns a list of existing action short_names in this workflow.
    Useful when you're trying to ensure a short_name is unique, 
    or construct a new short_name that is guaranteed to be unique.

    @param ignore_action_id   If specified, the short_name for the given action will not be included in the result set.
} {
    set result [list]

    foreach action_id [workflow::get_actions -workflow_id $workflow_id] {
        if { [empty_string_p $ignore_action_id] || ![string equal $ignore_action_id $action_id] } {
            lappend result [workflow::action::get_element -action_id $action_id -element short_name]
        }
    }

    return $result
}

ad_proc -public workflow::action::generate_short_name {
    {-workflow_id:required}
    {-pretty_name:required}
    {-short_name {}}
    {-action_id {}}
} {
    Generate a unique short_name from pretty_name.
    
    @param action_id    If you pass in this, we will allow that action's short_name to be reused.
    
} {
    set existing_short_names [workflow::action::get_existing_short_names \
                                  -workflow_id $workflow_id \
                                  -ignore_action_id $action_id]
    
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
            error "Action with short_name '$short_name' already exists in this workflow."
        }
    }

    return $short_name
}




######################################################################
#
# workflow::action::fsm
#
######################################################################

ad_proc -public workflow::action::fsm::new {
    {-workflow_id:required}
    {-action_id {}}
    {-sort_order {}}
    {-short_name {}}
    {-pretty_name:required}
    {-pretty_past_tense {}}
    {-edit_fields {}}
    {-allowed_roles {}}
    {-assigned_role {}}
    {-privileges {}}
    {-enabled_states {}}
    {-assigned_states {}}
    {-enabled_state_ids {}}
    {-assigned_state_ids {}}
    {-new_state {}}
    {-new_state_id {}}
    {-callbacks {}}
    {-always_enabled_p f}
    {-initial_action_p f}
    {-description {}}
    {-description_mime_type {}}
    {-timeout_seconds {}}
} {
    Add an action to a certain FSM (Finite State Machine) workflow. 
    This procedure invokes the generic workflow::action::new procedures 
    and does additional inserts for FSM specific information. See the 
    parameter documentation for the proc workflow::action::new.

    @return the new action_id.

    @see workflow::action::new

    @author Peter Marklund
} {        

    db_transaction {
        # Generic workflow data:
        set action_id [workflow::action::new \
                           -internal \
                           -initial_action_p $initial_action_p \
                           -workflow_id $workflow_id \
                           -action_id $action_id \
                           -sort_order $sort_order \
                           -short_name $short_name \
                           -pretty_name $pretty_name \
                           -pretty_past_tense $pretty_past_tense \
                           -edit_fields $edit_fields \
                           -allowed_roles $allowed_roles \
                           -assigned_role $assigned_role \
                           -privileges $privileges \
                           -callbacks $callbacks \
                           -always_enabled_p $always_enabled_p \
                           -description $description \
                           -description_mime_type $description_mime_type \
                           -timeout_seconds $timeout_seconds]

        # FSM specific information below

        # Record whether the action changes state
        if { ![empty_string_p $new_state] } {
            if { ![empty_string_p $new_state_id] } {
                error "You cannot supply both new_state (takes short_name) and new_state_id (takes state_id)"
            }
            set new_state_id [workflow::state::fsm::get_id \
                    -workflow_id $workflow_id \
                    -short_name $new_state]
        }
        db_dml insert_fsm_action {}

        array set update_cols [list]
        foreach col { enabled_states enabled_state_ids assigned_states assigned_state_ids } {
            if { ![empty_string_p [set $col]] } {
                set update_cols($col) [set $col]
            }
        }

        workflow::action::fsm::edit \
            -internal \
            -action_id $action_id \
            -workflow_id $workflow_id \
            -array update_cols

        workflow::definition_changed_handler -workflow_id $workflow_id
    }   
    
    # Flush the workflow cache, as changing an action changes the entire workflow
    # e.g. initial_action_p, enabled_in_states.
    workflow::flush_cache -workflow_id $workflow_id

    return $action_id
}

ad_proc -public workflow::action::fsm::edit {
    {-action_id:required}
    {-workflow_id {}}
    {-array:required}
    {-internal:boolean}
} {
    Edit an FSM action.

    @param action_id    The action to edit.

    @param workflow_id  Optionally specify  the workflow_id. If not specified, we will execute a query to find it.
    
    @param array        Name of an array in the caller's namespace with attributes to edit.

    @param internal               Set this flag if you're calling this proc from within the corresponding proc 
                                  for a particular workflow model. Will cause this proc to not flush the cache 
                                  or call workflow::definition_changed_handler, which the caller must then do.

    @return action_id
    
    @see workflow::action::fsm::new
} {
    upvar 1 $array org_row
    if { ![array exists org_row] } {
        error "Array $array does not exist or is not an array"
    }

    # We make a copy here and work on that, so the check for illegal attributes in workflow::action::edit works properly, 
    # i.e. we delete from 'row' before calling workflow::action::edit, but we don't touch the caller's row
    array set row [array get org_row]

    if { [empty_string_p $workflow_id] } {
        set workflow_id [workflow::action::get_element \
                             -action_id $action_id \
                             -element workflow_id]
    }

    db_transaction {

        # Record whether the action changes state
        if { [info exists row(new_state)] } {
            if { [info exists row(new_state_id)] } {
                error "You cannot supply both new_state (takes short_name) and new_state_id (takes state_id)"
            }
            if { ![empty_string_p $row(new_state)] } {
                set row(new_state_id) [workflow::state::fsm::get_id \
                                      -workflow_id $workflow_id \
                                      -short_name $new_state]
            } else {
                set row(new_state_id) [db_null]
            }
            unset row(new_state)
        }

        if { [info exists row(new_state_id)] } {
            set new_state_id $row(new_state_id)
            db_dml update_fsm_action {}
            unset row(new_state_id)
        }


        # Record in which states the action is enabled but not assigned
        if { [info exists row(enabled_states)] } {
            set assigned_p "f"
            db_dml delete_enabled_states {}
            foreach state_short_name $row(enabled_states) {
                set enabled_state_id [workflow::state::fsm::get_id \
                                          -workflow_id $workflow_id \
                                          -short_name $state_short_name]
                db_dml insert_enabled_state {}
            }
            unset row(enabled_states)
        } elseif { [info exists row(enabled_state_ids)] } {
            set assigned_p "f"
            db_dml delete_enabled_states {}
            foreach enabled_state_id $row(enabled_state_ids) {
                db_dml insert_enabled_state {}
            }
            unset row(enabled_state_ids)
        }

        # Record where the action is both enabled and assigned
        if { [info exists row(assigned_states)] } {
            set assigned_p "t"
            db_dml delete_enabled_states {}
            foreach state_short_name $row(assigned_states) {
                set enabled_state_id [workflow::state::fsm::get_id \
                                          -workflow_id $workflow_id \
                                          -short_name $state_short_name]
                db_dml insert_enabled_state {}
            }
            unset row(assigned_states)
        } elseif { [info exists row(assigned_state_ids)] } {
            set assigned_p "t"
            db_dml delete_enabled_states {}
            foreach enabled_state_id $row(assigned_state_ids) {
                db_dml insert_enabled_state {}
            }
            unset row(assigned_state_ids)
        }
 
        # This will error if there are attributes it doesn't know about, so we remove the attributes we know above
        workflow::action::edit \
            -internal \
            -action_id $action_id \
            -workflow_id $workflow_id \
            -array row

        if { !$internal_p } {
            workflow::definition_changed_handler -workflow_id $workflow_id
        }
    }

    if { !$internal_p } {
        # Flush the workflow cache, as changing an action changes the entire workflow
        # e.g. initial_action_p, enabled_in_states.
        workflow::flush_cache -workflow_id $workflow_id
    }
}


ad_proc -public workflow::action::fsm::delete {
    {-action_id:required}
} {
    Delete FSM action with given id.

    @author Peter Marklund
} {
    db_dml delete_action {
        delete from workflow_actions
        where action_id = :action_id
    }
}

ad_proc -public workflow::action::fsm::get_new_state {
    {-action_id:required}
} {
    Return the ID of the new state for an action
    @param action_id The action_id of the action.
    @return The ID of the new state after executing this action, or the empty string if the action doesn't change the state.
} {
    return [workflow::action::get_from_request_cache $action_id "new_state_id"]
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
        assigned_states {}
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
            -assigned_states $action(assigned_states) \
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
    array unset row new_state_id
    array unset row callbacks_array
    array unset row callback_ids
    array unset row allowed_roles_array
    array unset row allowed_role_ids

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

ad_proc -private workflow::action::flush_cache {
    {-workflow_id:required}
} {
    Flush all caches related to actions for the given
    workflow_id. Used internally by the workflow API only.

    @author Peter Marklund
} {
    # Flush the request cache
    global __workflow_action_data,${workflow_id}
    if { [info exists __workflow_action_data,${workflow_id}] } {
        foreach action_id [set __workflow_action_data,${workflow_id}(action_ids)] {
            global __workflow_one_action,$action_id
            
            if { [info exists __workflow_one_action,$action_id] } {
                unset __workflow_one_action,$action_id
            }
        }

        unset __workflow_action_data,${workflow_id}
    }

    # Flush the thread global cache
    util_memoize_flush [list workflow::action::get_all_info_not_cached -workflow_id $workflow_id]
}

ad_proc -private workflow::action::refresh_request_cache { workflow_id } {
    Initializes the cached array with information about actions for a certain workflow
    so that it can be reused within one request.

    @author Peter Marklund
} {
    global __workflow_action_data,${workflow_id}

    if { ![info exists __workflow_action_data,${workflow_id}] } {
        array set __workflow_action_data,${workflow_id} [workflow::action::get_all_info -workflow_id $workflow_id]
    }
}
    
ad_proc -private workflow::action::get_from_request_cache {
    action_id
    {element ""}
} {
    This provides some abstraction for the Workflow API cache
    and also some optimization - we only convert lists to 
    arrays once per request. Should be used internally
    by the workflow API only.

    @author Peter Marklund
} {
    # Get the cache with all actions
    set workflow_id [workflow::action::get_workflow_id -action_id $action_id]
    refresh_request_cache $workflow_id
    global __workflow_action_data,${workflow_id}

    array set workflow_data [workflow::action::get_all_info -workflow_id $workflow_id]

    # A single action
    set action_var_name __workflow_one_action,${action_id}
    global $action_var_name

    if { ![info exists $action_var_name] } {
        array set $action_var_name [set __workflow_action_data,${workflow_id}($action_id)]
    }

    if { [empty_string_p $element] } {
        return [array get $action_var_name]
    } else {
        return [set "${action_var_name}($element)"]
    }
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
    array set actions [list]

    foreach action_id [workflow::get_actions -workflow_id $workflow_id] {
        lappend actions_list [get_element -action_id $action_id -element short_name] [generate_spec -action_id $action_id]
    }

    return $actions_list

}

ad_proc -private workflow::action::get_all_info {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only.
    Returns all information related to actions for a certain
    workflow instance. Uses util_memoize to cache values.

    @see workflow::action::get_all_info_not_cached

    @author Peter Marklund
} {
    return [util_memoize [list workflow::action::get_all_info_not_cached \
            -workflow_id $workflow_id] [workflow::cache_timeout]]
}

ad_proc -private workflow::action::get_all_info_not_cached {
    {-workflow_id:required}
} {
    This proc is for internal use in the workflow API only and
    should not be invoked directly from application code. Returns
    all information related to actions for a certain workflow instance.
    Goes to the database on every invocation and should be used together
    with util_memoize.

    @author Peter Marklund
} {
    # We avoid nested db queries in this proc to enhance performance

    # Put scalar action data into the master array and use
    # a list of action_id:s for sorting purposes
    array set action_data {}
    set action_ids [list]
    db_foreach action_info {} -column_array action_row {

        # Cache the mapping action_id -> workflow_id
        util_memoize_seed \
                [list workflow::action::get_workflow_id_not_cached -action_id $action_row(action_id)] \
                $workflow_id

        set action_data($action_row(action_id)) [array get action_row]
        lappend action_ids $action_row(action_id)
    }
    
    # Build a separate array for all action callbacks of the workflow
    array set callbacks_array {}
    array set callbacks {}
    array set callback_ids_array {}
    set callback_ids [list]
    set last_action_id ""
    db_foreach action_callbacks {} -column_array callback_row {
        set callbacks_array($callback_row(action_id),$callback_row(impl_id)) [array get callback_row]
        lappend callbacks($callback_row(action_id)) \
                "$callback_row(impl_owner_name).$callback_row(impl_name)"
        
        if { ![string equal $last_action_id $callback_row(action_id)] } {
            set callback_ids_array($last_action_id) $callback_ids
            set callback_ids [list]
        }
        lappend callback_ids $callback_row(impl_id)
        set last_action_id $callback_row(action_id)
    } 
    # Peter had forgotten this at the end of the loop
    set callback_ids_array($last_action_id) $callback_ids

    # Build an array for all allowed roles for all actions
    array set allowed_roles_array {}
    array set allowed_roles {}
    array set allowed_role_ids {}
    db_foreach action_allowed_roles {} -column_array allowed_role_row {
        set allowed_roles_array($allowed_role_row(action_id),$allowed_role_row(role_id)) [array get allowed_role_row]
        lappend allowed_roles($allowed_role_row(action_id)) $allowed_role_row(short_name)
        lappend allowed_role_ids($allowed_role_row(action_id)) $allowed_role_row(role_id)
    }

    # Build an array  of privileges for all actions
    array set privileges {}
    db_foreach select_privileges {} {
        lappend privileges($action_id) $privilege
    }

    # Build arrays of enabled and assigned state short names for all actions
    array set enabled_states {}
    array set enabled_state_ids {}
    array set assigned_states {}
    array set assigned_state_ids {}
    db_foreach action_enabled_in_states {} {
        if { [string equal $assigned_p "t"] } {
            lappend assigned_states($action_id) $short_name
            lappend assigned_state_ids($action_id) $state_id
        } else {
            lappend enabled_states($action_id) $short_name
            lappend enabled_state_ids($action_id) $state_id
        }
    }

    # For each action_id, add to the array of that action the contents of the
    # sub arrays (callbacks, allowed_roles, allowed_role_ids, privileges)
    foreach action_id $action_ids {
        array set one_action $action_data($action_id)

        foreach array_name { privileges enabled_states enabled_state_ids assigned_states assigned_state_ids callbacks allowed_roles allowed_role_ids } {
            if { [info exists ${array_name}($action_id)] } {
                set one_action(${array_name}) [set ${array_name}($action_id)]
            } else {
                set one_action(${array_name}) {}
            }
        }

        set id_len [expr [string length $action_id] + 1]
        foreach array_name { callbacks_array allowed_roles_array } {
            set one_action($array_name) [list]
            foreach { key value } [array get $array_name "${action_id},*"] {
                lappend one_action($array_name) [string range $key $id_len end] $value
            }
        }

        if { [info exists callback_ids_array($action_id)] } {
            set one_action(callback_ids) $callback_ids_array($action_id)
        } else {
            set one_action(callback_ids) [list]
        }

        set action_data($action_id) [array get one_action]

        # Have to unset the array as otherwise array set will append to previous values
        unset one_action
    }

    set action_data(action_ids) $action_ids

    return [array get action_data]
}
