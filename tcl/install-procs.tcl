ad_library {
    Procedures for initializing service contracts etc. for the
    workflow package. Should only be executed once upon installation.
    
    @creation-date 13 January 2003
    @author Lars Pind (lars@collaboraid.biz)
    @author Peter Marklund (peter@collaboraid.biz)
    @cvs-id $Id$
}

namespace eval workflow::install {}



#####
#
# Install procs
#
#####

ad_proc -private workflow::install::package_install {} {
    Workflow package install proc
} {

    db_transaction {

        create_service_contracts

        register_implementations
        
    }
}

ad_proc -private workflow::install::package_uninstall {} {
    Workflow package uninstall proc
} {

    db_transaction {

        delete_service_contracts

        unregister_implementations
        
    }
}


#####
#
# Create service contracts
#
#####

ad_proc -private workflow::install::create_service_contracts {} {
    Create the service contracts needed by workflow
} {

    db_transaction {

        workflow::install::create_default_assignees_service_contract

        workflow::install::create_assignee_pick_list_service_contract

        workflow::install::create_assignee_subquery_service_contract

        workflow::install::create_action_side_effect_service_contract

        workflow::install::create_activity_log_format_title_service_contract

    }
}


ad_proc -private workflow::install::delete_service_contracts {} {
    
    db_transaction {

        acs_sc::contract::delete -name [workflow::service_contract::role_default_assignees]
        
        acs_sc::contract::delete -name [workflow::service_contract::role_assignee_pick_list]
        
        acs_sc::contract::delete -name [workflow::service_contract::role_assignee_subquery]

        acs_sc::contract::delete -name [workflow::service_contract::action_side_effect]

        acs_sc::contract::delete -name [workflow::service_contract::activity_log_format_title]
    
    }
}
    
ad_proc -private workflow::install::create_default_assignees_service_contract {} {

    set default_assignees_spec {
        description "Get default assignees for a role in a workflow case"
        operations {
            GetObjectType {
                description "Get the object type for which this implementation is valid."
                output { object_type:string }
                iscachable_p "t"
            }
            GetPrettyName {
                description "Get the pretty name of this implementation. Will be localized, so i may contain #...#."
                output { pretty_name:string }
                iscachable_p "t"
            }
            GetAssignees {
                description "Get the assignees as a Tcl list of party_ids, of the default assignees for this case, object, role"
                input {
                    case_id:integer
                    object_id:integer
                    role_id:integer
                }
                output {
                    party_ids:integer,multiple
                }
            }
        }
    }

    acs_sc::contract::new_from_spec \
            -spec [concat [list name [workflow::service_contract::role_default_assignees]] $default_assignees_spec]
}

ad_proc -private workflow::install::create_assignee_pick_list_service_contract {} {

    set assignee_pick_list_spec {
        description "Get the most likely assignees for a role in a workflow case"
        operations {
            GetObjectType {
                description "Get the object type for which this implementation is valid."
                output { object_type:string }
                iscachable_p "t"
            }
            GetPrettyName {
                description "Get the pretty name of this implementation. Will be localized, so i may contain #...#."
                output { pretty_name:string }
                iscachable_p "t"
            }
            GetPickList {
                description "Get the most likely assignees for this case, object and role, as a Tcl list of party_ids"
                input {
                    case_id:integer
                    object_id:integer
                    role_id:integer
                }
                output {
                    party_ids:integer,multiple
                }
            }
        }
    }

    acs_sc::contract::new_from_spec \
            -spec [concat [list name [workflow::service_contract::role_assignee_pick_list]] $assignee_pick_list_spec]
}

ad_proc -private workflow::install::create_assignee_subquery_service_contract {} {
    
    set assignee_subquery_spec {
        description "Get the name of a subquery to use when searching for users"
        operations {
            GetObjectType {
                description "Get the object type for which this implementation is valid."
                output { object_type:string }
                iscachable_p "t"
            }
            GetPrettyName {
                description "Get the pretty name of this implementation. Will be localized, so i may contain #...#."
                output { pretty_name:string }
                iscachable_p "t"
            }
            GetSubQueryName {
                description "Get the Query Dispatcher query name of the query which will return the list of parties who can be assigned to the role, and optionally bind variables to be filled in. Names of bind variables cannot start with an underscore (_)."
                input {
                    case_id:integer
                    object_id:integer
                    role_id:integer
                }
                output {
                    subquery_name:string
                    bind:string,multiple
                }
            }
        }
    }

    acs_sc::contract::new_from_spec \
            -spec [concat [list name [workflow::service_contract::role_assignee_subquery]] $assignee_subquery_spec]
}

ad_proc -private workflow::install::create_action_side_effect_service_contract {} {

    set side_effect_spec {
        description "Get the name of the side effect to create action"
        operations {
            GetObjectType {
                description "Get the object type for which this implementation is valid."
                output { object_type:string }
                iscachable_p "t"
            }
            GetPrettyName { 
                description "Get the pretty name of this implementation. Will be localized, so it may contain #...#."
                output { object_type:string }
                iscachable_p "t"
            }
            DoSideEffect {
                description "Do the side effect"
                input {
                    case_id:integer
                    object_id:integer
                    action_id:integer
                    entry_id:integer
                }
            }
        } 
    }  
    
    acs_sc::contract::new_from_spec \
            -spec [concat [list name [workflow::service_contract::action_side_effect]] $side_effect_spec]
    
}

ad_proc -private workflow::install::create_activity_log_format_title_service_contract {} {
        
    set format_title_spec {
        description "Create the title format for activity log"
        operations {
            GetObjectType {
                description "Get the object type for which this implementation is valid."
                output {
                    object_type:string
                }
                iscachable_p "t"
            }
            GetPrettyName {
                description "Get the pretty name of this implementation. Will be localized, so it may contain #...#."
                output { object_type:string }
                iscachable_p "t"
            }
            GetTitle {
                description "Get the title name of this implementation."
                input { 
                    entry_id:integer 
                } 
                output { 
                    title:string 
                }
                iscachable_p "t"
            }
        }
    }
    
    acs_sc::contract::new_from_spec \
            -spec [concat [list name [workflow::service_contract::activity_log_format_title]] $format_title_spec]
}

#####
#
# Register implementations
#
#####

ad_proc -private workflow::install::register_implementations {} {
    Register service contract implementations
} { 

    db_transaction {

        workflow::install::register_default_assignees_creation_user_impl

        workflow::install::register_default_assignees_static_assignee_impl

        workflow::install::register_pick_list_current_assignee_impl 
    }
}

ad_proc -private workflow::install::unregister_implementations {} {
    Unregister service contract implementations
} {

    db_transaction {

        acs_sc::impl::delete \
                -contract_name [workflow::service_contract::role_default_assignees]  \
                -impl_name "Role_DefaultAssignees_CreationUser"

        acs_sc::impl::delete \
                -contract_name [workflow::service_contract::role_default_assignees] \
                -impl_name "Role_DefaultAssignees_StaticAssignees"

        acs_sc::impl::delete \
                -contract_name [workflow::service_contract::role_assignee_pick_list] \
                -impl_name "Role_PickList_CurrentAssignees"
    }
}

ad_proc -private workflow::install::register_default_assignees_creation_user_impl {} {

    set spec {
        name "Role_DefaultAssignees_CreationUser"
        aliases {
            GetObjectType workflow::impl::acs_object
            GetPrettyName workflow::impl::role_default_assignees::creation_user::pretty_name
            GetAssignees  workflow::impl::role_default_assignees::creation_user::get_assignees
        }
    }
    
    lappend spec contract_name [workflow::service_contract::role_default_assignees] 
    lappend spec owner [workflow::package_key]
    
    acs_sc::impl::new_from_spec -spec $spec
}

ad_proc -private workflow::install::register_default_assignees_static_assignee_impl {} {

    set spec {
        name "Role_DefaultAssignees_StaticAssignees"
        aliases {
            GetObjectType workflow::impl::acs_object
            GetPrettyName workflow::impl::role_default_assignees::static_assignees::pretty_name
            GetAssignees  workflow::impl::role_default_assignees::static_assignees::get_assignees
        }
    }
    
    lappend spec contract_name [workflow::service_contract::role_default_assignees] 
    lappend spec owner [workflow::package_key]
    
    acs_sc::impl::new_from_spec -spec $spec
}

ad_proc -private workflow::install::register_pick_list_current_assignee_impl {} {

    set spec {
        name "Role_PickList_CurrentAssignees"
        aliases {
            GetObjectType workflow::impl::acs_object
            GetPrettyName workflow::impl::role_assignee_pick_list::pretty_name
            GetPickList   workflow::impl::role_assignee_pick_list::get_pick_list 
        }  
    }

    lappend spec contract_name [workflow::service_contract::role_assignee_pick_list]
    lappend spec owner [workflow::package_key]

    acs_sc::impl::new_from_spec -spec $spec
}