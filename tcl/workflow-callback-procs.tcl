ad_library {
    ad_proc -callback procs for workflow
}

ad_proc -callback workflow::case::role::after_assign {
    {-case_id:required}
    {-party_id:required}
} {
    After assignment callback to execute arbitrary code after
    a party is assigned to a role.
} -

ad_proc -callback workflow::case::role::after_unassign {
    {-case_id:required}
    {-party_id:required}
} {
    After assignment callback to execute arbitrary code after
    a party is unassigned from a role.
} -