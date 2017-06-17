
<property name="context">{/doc/workflow {Workflow}} {Fall 2003 Workflow Extensions Requirements and
Design}</property>
<property name="doc(title)">Fall 2003 Workflow Extensions Requirements and
Design</property>
<master>
<h1>Fall 2003 Workflow Extensions</h1>
<a href=".">Workflow Documentation</a>
 : Fall 2003 Workflow
Extensions
<p>By Lars Pind
</p>
<p>This requirements and design document is primarily motivated
by:</p>
<ul>
<li>A client project developing the Simulation package (in CVS at
openacs.org:/cvsroot openacs-4/contrib/packages/simulation), which
is a workflow-based law simulation engine.</li><li>The need for an application that can handle the TIP voting
process.</li>
</ul>
<ul>
<li><a href="#hierarchy">Hierarchical Workflows</a></li><li><a href="#hierarchy2">Hierarchical Workflows, Design 2</a></li><li><a href="#trigger-conditions">Trigger Conditions</a></li><li><a href="#case-state">Case State</a></li><li><a href="#conditional-transformation">Conditional
Transformation For Atomic Actions</a></li><li><a href="#conditional-child">Conditional Transformation Based
on Child Workflows</a></li><li><a href="#gated-actions">Gated Actions</a></li><li><a href="#enable-callback">Enable Condition Callback</a></li><li><a href="#non-user-trigger">Non-User Triggered Actions</a></li><li><a href="#resolution-codes">Resolution Codes</a></li><li><a href="#assignment-notif">Assignment Notifications</a></li><li><a href="#assignment-reminder">Assignment Reminders</a></li><li><a href="#trying-to-sum-up">Trying to Sum Up</a></li><li><a href="#timers">Timers</a></li>
</ul>
<h2><a name="hierarchy" id="hierarchy">Hierarchical
Workflows</a></h2>
<h3>Requirements</h3>
<p>Use cases:</p>
<ul>
<li>Leiden: We have several occurrences of the simple
AskInfo-GiveInfo question/response pair. Defining simulation
templates would be simplified if that was a reusable
component.</li><li>TIP Voting: There&#39;s a master workflow case for the TIP
itself. When voting, there&#39;ll be a sub-workflow case for each
TIP member to vote on the issue, with timeouts so if they don&#39;t
vote within a week, their vote is automatically
'Abstained'.</li>
</ul>
<h3>Questions we need answered by the design</h3>
<ol>
<li>Which actions are enabled?</li><li>How is the state changed after this action has executed?</li><li>Which roles are assigned/allowed to perform an action?</li><li>Which roles do a user play?</li><li>What is the activity history on this case?</li><li>What is the name of this action?</li><li>How do we clone a workflow?</li>
</ol>
<h3>Design</h3>
<ul>
<li>Actions will no longer be atomic. An action can be "in
progress" for a long time, while the child workflow(s)
completes.</li><li>We will introduce an uber-state of a case, which can be
'active', 'completed', 'canceled', or
'suspended'.</li><li>When the action gets enabled, a callback will create child
cases linked to this particular enabled action.</li><li>Whenever a child case changes its case_state, a callback on the
parent action is invoked, which examines the state of all of its
child cases and determines whether the parent action is complete
and ready to fire or not. If the parent action is completed, any
remaining 'active' child cases will be marked
'canceled'.</li><li>If the action should ever get un-enabled, a callback will
cancel all remaining 'active' child cases.</li><li>If the action becomes enabled again, we will create new child
cases.</li><li>A case which is a child of another case cannot leave the
'completed' or 'canceled' state, unless its parent
enabled action is still enabled.</li>
</ul>
<h4>Data Model</h4>
<pre>
create table workflow_action_children(
  child_id                  integer
                            constraint ...
                            primary key,
  action_id                 integer
                            constraint ...
                            not null
                            constraint ...
                            references workflow_actions(action_id)
                            on delete cascade,
  child_workflow            integer
                            constraint wf_action_child_wf_fk
                            references workflows(workflow_id)
);

create table workflow_action_child_role_map(
  parent_action_id          integer
                            constraint wf_act_chid_rl_map_prnt_act_fk
                            references workflow_actions(action_id),
  parent_role               integer
                            constraint wf_act_chid_rl_map_prnt_rl_fk
                            references workflow_roles(role_id),
  child_role                integer
                            constraint wf_act_chid_rl_map_chld_rl_fk
                            references workflow_roles(role_id),
  mapping_type              char(40)
                            constraint wf_act_chid_rl_map_type_ck
                            check (mapping_type in 
                                ('per_role','per_member','per_user'))
);

create table workflow_case_enabled_actions(
  enabled_action_id         integer
                            constraint wf_case_enbl_act_case_id_pk
                            primary key,
  case_id                   integer
                            constraint wf_case_enbl_act_case_id_nn
                            not null
                            constraint wf_case_enbl_act_case_id_fk
                            references workflow_cases(case_id)
                            on delete cascade,
  action_id                 integer
                            constraint wf_case_enbl_act_action_id_nn
                            not null
                            constraint wf_case_enbl_act_action_id_fk
                            references workflow_actions(action_id)
                            on delete cascade,
  enabled_state             char(40)
                            constraint wf_case_enbl_act_state_ck
                            check (enabled_state in ('enabled','running','completed','canceled','refused')),
  -- the timestamp when this action automatically fires
  fire_timestamp            timestamp
                            constraint wf_case_enbl_act_timeout_nn
                            not null,
  constraint wf_case_ena_act_case_act_un
  primary key (case_id, action_id)
);

create table workflow_case_child_cases(
  case_id                 integer 
                          constraint wf_case_child_cases_case_fk
                          references workflow_cases
                          constraint wf_case_child_cases_case_pk
                          primary key,
  enabled_action_id       integer
                          constraint wf_case_child_cases_en_act_fk
                          references workflow_case_enabled_actions
                          constraint wf_case_child_cases_en_act_nn
                          not null
);
</pre>
<h4>Enabled States Explained</h4>
<p>The enabled_state of rows in workflow_case_enabled_actions can
be in one of the following:</p>
<ul>
<li>
<strong>Enabled</strong>. The action is currently enabled.</li><li>
<strong>Running</strong>. The action is currently running,
specifically meaning that there are active child cases.
XXXXXXXXXXXXXX do we need this?</li><li>
<strong>Completed</strong>. The action has completed executing.
The row will still stay around so we have a history of what was
executed when and we&#39;re able to count the number of times a
given action was executed.</li><li>
<strong>Canceled</strong>. The action was enabled, but the
case&#39;s state changed before the action was triggered. (Note:
This is not necessary, we could just delete the row instead.)</li><li>
<strong>Refused</strong>. The action had its database-driven
preconditions for being enabled met (e.g. enabled-in-states for
FSM, input places with tokens in Petri, plus dependencies on other
tasks met), but the "CanEnableP" callback refused to let
the action become enabled. (Note: This is not necessary, we could
just delete the row instead.)</li>
</ul>
<h4>When Enabled</h4>
<p>When an action with child workflows is enabled, we start the
child cases defined by the parent workflow, executing the initial
action on each of them.</p>
<p>We create one case per role in workflow_action_children times
one case per member/user for roles with a mapping_type of
'per_member'/'per_user'. If more than one role has
a mapping_type other than 'per_role', we will create cases
for the cartesian product of members/users of those roles in the
parent workflow.</p>
<h4>When Triggered</h4>
<p>The action can be triggered by a timeout, by the user, by child
cases reaching a certain state, or by all child cases being
completed.</p>
<p>An example of "child cases reaching a certain state"
would be the TIP voting process, where 2/3rd Approved votes is
enough to determine the outcome, and we don&#39;t need the rest to
vote anymore.</p>
<p>When triggered, all child cases with a case_state of
'active' are put into the 'canceled' state. All
child cases have their 'locked_p' flag set to true, so they
cannot be reopened.</p>
<h2><a name="hierarchy2" id="hierarchy2">Hierarchy, Design
2</a></h2>
<pre>
----------------------------------------------------------------------
-- Knowledge level
----------------------------------------------------------------------

create table workflows(
);

create table workflow_roles(
);

create table workflow_actions(
  action_id                 integer primary key
  ...
  parent_action_id          integer references workflow_actions,
  assigned_role             integer references workflow_roles
  trigger_type              char(40)
                            constraint wf_case_enbl_act_trig_type_ck
                            check (trigger_type in ('user','auto','message','workflow','parallel','dynamic')),
  ...
);

create table workflow_fsm_states(
  state_id                  integer primary key
  ...
  parent_action_id          integer references workflow_actions
);


----------------------------------------------------------------------
-- Operational level
----------------------------------------------------------------------

create table workflow_case_fsm(
  case_id
  action_id
  state_id
);

create table workflow_case_actions(
  case_id                   integer references workflow_cases
  action_id                 integer references workflow_actions
  assigned_p                boolean
  execution_time            timestamptz
);
</pre>
<h3>Example I: Simple AskInfo/GiveInfo Pair</h3>
<pre>
roles                 role_id
                     ---------            
                      lawyer
                      client

actions               action_id    | parent_action_id | assigned_role | trigger_type | new_state  
                     --------------+------------------+---------------+--------------+---------------
                      init         |                  |               | init         | open
                      ask client   |                  |               | workflow     | done       
                        ac-init    | ask client       |               | init         | ac-asking
                        ac-ask     | ask client       | lawyer        | user         | ac-responding
                        ac-respond | ask client       | client        | user         | ac-done    
                      abort        |                  | judge         | user         | done       

states                state_id      | parent_action_id
                     ---------------+------------------
                      open          | 
                      done          |
                      ac-asking     | ask client
                      ac-responding | ask client
                      ac-done       | ask client

state_action_map      state_id      | action_id
                     ---------------+------------
                      open          | ask client
                      open          | abort
                      ac-asking     | ac-ask
                      ac-responding | ac-respond

case_state            action_id  | state_id
                     ------------+---------
                                 | open
                      ask client | ac-asking

case_enabled_actions   ID | action_id  | parent_enabled_action_id | assigned_p
                      ----+------------+--------------------------+------------
                       #1 | ask client |                          | no                       
                       #2 | ac-ask     | #1                       | yes
                       #3 | abort      |                          | no
</pre>
<ol>
<li>case::enabled_actions -case_id
<ol>
<li>Find the case state (open)</li><li>Find the actions enabled in this state (ask client, abort)</li><li>"abort" is final, put it on the list.</li><li>"ask client" has a child; look in
workflow_enabled_actions for the state</li><li>If there&#39;s no row in enabled actions for "ask
client", execute "ac-init", which will set
case_enabled_actions.state_id to ac-asking for case_id #1 and
action_id "ask client".</li><li>Look in case_enabled_actions.state_id for case_id #1 and
action_id "ask client" for the substate (ac-asking).</li><li>Find the enabled actions in the ac-asking state (ac-ask).</li><li>ac-ask is final, put it on the list</li>
</ol>
</li><li>case::action::execute -case_id -action_id
<ol>
<li>The question is which state to change.</li><li>Find the action&#39;s parent_action_id</li><li>If null, then change cases.state_id</li><li>Otherwise, change case_enabled_actions.state_id.</li>
</ol>
</li><li>Which roles are assigned/allowed to perform an action?
Unchanged from current design.</li><li>Which roles do a user play? Unchanged from current design.</li><li>What is the activity history on this case? Unchanged from
current design.</li><li>What is the name of this action? Unchanged from current
design.</li><li>How do we clone a workflow?
<ol><li>We need to have a provision for actions to include other
actions in the spec.</li></ol>
</li>
</ol>
<h3>Notes</h3>
<ul>
<li>Keeping the sub-state in the workflow_case_enabled_actions
table.</li><li>Kill the completed rows in workflow_case_enabled_actions, move
stuff into the case-log instead =&gt; that&#39;s going to be much,
much better for performance.</li>
</ul>
<h3>Design 2, Parallel Actions</h3>
<h3>Example II: Parallel</h3>
<pre>
roles                 role_id
                     ---------            
                      lawyer
                      client

actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
                     ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      rev &amp; op       |                  |               | parallel     | done
                        review-wr    | rev &amp; op         |               | workflow     | 
                          rev-init   | review-wr        |               | init         | rev-open
                          review     | review-wr        | lawyer        | user         | rev-done
                        opinion-wr   | rev &amp; op         |               | workflow     | 
                          opi-init   | opinion-wr       |               | init         | opi-open
                          opinion    | opinion-wr       | lawyer        | user         | opi-done

states                state_id      | parent_action_id
                     ---------------+------------------
                      open          | 
                      done          |
                      rev-open      | review-wr
                      rev-done      | review-wr
                      opi-open      | opinion-wr
                      opi-done      | opinion-wr

state_action_map      state_id      | action_id
                     ---------------+------------
                      open          | rev &amp; op
                      rev-open      | review
                      opi-open      | opinion

case_state            action_id  | state_id
                     ------------+---------
                                 | open
                      review-wr  | rev-open
                      opinion-wr | opi-open

case_enabled_actions   ID | action_id    | parent_enabled_action_id | assigned_p
                      ----+--------------+--------------------------+-----------
                       #1 | rev &amp; op     |                          | no                       
                       #2 |   review-wr  | #1                       | no
                       #3 |     review   | #2                       | yes
                       #4 |   opinion-wr | #1                       | no
                       #5 |     opinion  | #4                       | yes
</pre>
<ol><li>case::action::execute -case_id #1 -action_id "init"
<ol>
<li>set cases.state_id to init&#39;s new_state
("open")</li><li>call case::state_changed_handler -case_id #1
<ol>
<li>find enabled actions by looking in state_action_map under the
current state (open) =&gt; (rev &amp; op)</li><li>foreach enabled action, see if it was already enabled. if so,
skip to next action. (not already enabled)</li><li>if not, call case::action::enable -action_id (rev &amp; op)
<ol>
<li>insert row into case_enabled_actions (rev &amp; op)</li><li>foreach sub-action, call case::action::enable -action_id
(review-wr, opinion-wr)
<ol>
<li>insert row into case_enabled_actions (review-mr)</li><li>foreach sub-action, call case::action::enable -action_id
(review-wr, opinion-wr)</li>
</ol><ol><li>insert row into case_enabled_actions (opinion-mr)</li></ol>
</li>
</ol>
</li>
</ol>
</li>
</ol>
</li></ol>
<p>Difference between parallel sub-actions and non-parallel
sub-actions: If they are parallel, we enable all of them and
don&#39;t maintain state there; if they&#39;re not, we look for an
init-action, and do maintain state.</p>
<pre>
actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
(workflow)           ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      ask client     |                  |               | workflow     | done       
                        ac-init      | ask client       |               | init         | ac-asking
                        ac-ask       | ask client       | lawyer        | user         | ac-responding
                        ac-respond   | ask client       | client        | user         | ac-done    
                      abort          |                  | judge         | user         | done       

actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
(parallel)           ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      rev &amp; op       |                  |               | parallel     | done
                        review-wr    | rev &amp; op         |               | workflow     | 
                          rev-init   | review-wr        | lawyer        | init         | rev-open
                          review     | review-wr        | lawyer        | user         | rev-done
                        opinion-wr   | rev &amp; op         |               | workflow     | 
                          opi-init   | opinion-wr       | lawyer        | init         | opi-open
                          opinion    | opinion-wr       | lawyer        | user         | opi-done
</pre>
<p>An action with type 'workflow' will maintain state
inside itself.</p>
<p>Can we do away with the extra layer of 'workflow' inside
the 'parallel' track? How do we know that the child
workflow has been completed -- i guess we do, because we keep the
state until its parent is gone...</p>
<pre>
actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
(parallel-simple)    ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      rev &amp; op       |                  |               | parallel     | done
                        review       | rev &amp; op         | lawyer        | user         | 
                        opinion      | rev &amp; op         | lawyer        | user         | 


states                state_id      | parent_action_id
                     ---------------+------------------
                      open          | 
                      done          | 

state_action_map      state_id      | action_id
                     ---------------+------------
                      open          | rev &amp; op

case_enabled_actions   ID | action_id    | parent_enabled_action_id | assigned_p | completed_p 
                      ----+--------------+--------------------------+------------+-------------
                       #1 | rev &amp; op     |                          | no         | no
                       #2 |   review     | #1                       | yes        | no
                       #3 |   opinion    | #1                       | yes        | no

</pre>
<p>Simple: We&#39;d have to keep the row in case_enabled_actions
around with completed_p = yes until the parent action is also
complete. When an action is completed, it deletes the rows for all
its children. If the action does not have a parent action, we
delete the row (thus we don&#39;t keep completed_p rows around for
top-level actions).</p>
<h3>Design 2, Action-Per-User (Or Dynamic Number of Parallel
Actions With Different Assignees)</h3>
<pre>
actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
(dynamic-simple)     ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      all-votes      |                  |               | dynamic      | done
                        vote         | all-votes        | voters        | user         | 

states                state_id      | parent_action_id
                     ---------------+------------------
                      open          | 
                      done          | 

state_action_map      state_id      | action_id
                     ---------------+------------
                      open          | all-votes

case_enabled_actions   enabled_action_id | action_id    | parent_enabled_action_id | assigned_p | completed_p 
                      -------------------+--------------+--------------------------+------------+-------------
                       #A                | all-vote     |                          | no         | no   
                       #B                |   vote       | #A                       | yes        | no
                       #C                |   vote       | #A                       | yes        | no

case_action_assignees  enabled_action_id | party_id 
                      -------------------+----------
                       #B                | malte
                       #C                | peter
</pre>
<pre>
actions               action_id      | parent_action_id | assigned_role | trigger_type | new_state  
(dynamic-workflow)   ----------------+------------------+---------------+--------------+---------------
                      init           |                  |               | init         | open
                      all-votes      |                  |               | dynamic      | voted
                        vote         | all-vote         |               | workflow     | 
                          init       | vote             |               | init         | vote-voting
                          approve    | vote             | voters        | user         | vote-approved
                          reject     | vote             | voters        | user         | vote-rejected
                      withdraw       |                  | submitter     | user         | withdrawn

states                state_id      | parent_action_id
                     ---------------+------------------
                      open          | 
                      vote-voting   | vote
                      vote-approved | vote
                      vote-rejected | vote

state_action_map      state_id      | action_id
                     ---------------+------------
                      open          | all-votes
                      vote-voting   | approve
                      vote-voting   | reject

case_state            enabled_action_id  | state_id
                     --------------------+---------
                                         | open
                      #B                 | vote-voting
                      #E                 | vote-voting

case_enabled_actions  ID | action_id    | parent_enabled_action_id | assigned_p | completed_p | assigned_role
                     ----+--------------+--------------------------+------------+-------------+---------------
                      #A | all-votes    |                          | no         | no          | 
                      #B |   vote       | #A                       | yes        | no          | 
                      #C |     approve  | #B                       | yes        | no          | 
                      #D |     reject   | #B                       | yes        | no          | 
                      #E |   vote       | #A                       | yes        | no          | 
                      #F |     approve  | #E                       | yes        | no          | 
                      #G |     reject   | #E                       | yes        | no          | 
                      #H | withdraw     |                          | yes        | no          | submitter


case_action_assignees  enabled_action_id | party_id
                      -------------------+------------
                       #B                | malte
                       #D                | malte
                       #F                | peter
                       #G                | peter
</pre>
<p>When a dynamic action is enabled, we create new enabled_action
rows for each of the child actions/workflows needed</p>
<h3>Views</h3>
<ul>
<li>Enabled? Action is enabled if:
<ol>
<li>It has workflow_actions.always_enabled_p = true</li><li>There is a row in workflow_fsm_action_en_in_st for the current
state and the given action.</li>
</ol>
</li><li>Assigned? It&#39;s assigned if: trigger_type = 'user',
state-action map has assigned_p = true, it has an
assigned_role.</li><li>What&#39;s the assigned role? (For dynamic actions, there may
not be an assigend role, if the assignees are in the
workflow_case_action_assignees table.) Pick the parties from the
workflow_case_role_map.</li><li>Who are the assignees?
<ol>
<li>Find the users:
<ol>
<li>Find the parties:
<ol>
<li>If there are rows in workflow_case_action_assignees for the
action, that&#39;s the parties.</li><li>Otherwise, the parties are in the workflow_case_role_map for
role workflow_actions.assigned_role.</li>
</ol>
</li><li>Use party_approved_member_map to find the users.</li>
</ol>
</li><li>Use the workflow_deputies table to find the actual users.</li>
</ol>
</li>
</ul>
<h3>Engine Algorithms</h3>
<pre>
state_changed_handler
--------------------
- find all actually enabled actions
  - chase the action-state-map for all current_states
  - add children of enabled actions, where the child has always_enabled_p = true, 
    or the parent has trigger_type = parallel or dynamic.
- enable all new actions

enable
------
- if trigger_type = workflow, find and execute child action with trigger_type = init.
- if trigger_type = parallel, find subactions and ::enable them
- if trigger_type = dynamic, we&#39;ll need code to determine which children to ::enable, and how to create them

execute_state_change
--------------------
- if action.new_state not null
  - if there&#39;s a state with the same parent_action_id as the action being executed, update that state with new_state
  - otherwise insert row with new_state

complete
--------
- if action.parent_action_id not null
  - set workflow_case_enabled_actions.completed_p = true
  - call child_state_changed_handler -action_id $parent_action_id
- otherwise, delete row in workflow_case_enabled_actions
  - delete all child rows

child_state_changed_handler
---------------------------
- trigger_type = workflow/parallel/dynamic:
  - if there are no actions with parent_action_id = :action_id, completed_p = false, 
    then call ::action::execute on the parent action


calculating the actual state-action map (which we can do later, if we want to)
------------------------------------------------------------------------------
- apply the state-action mapping table
- add always-enabled actions with parent_id to the states in which their parent is enabled (or all, if no parent)
- add actions with parent.trigger_type dynamic/parallel to states in which their parent is enabled
</pre>
<pre>
always_enabled_p
----------------
- if parent_action_id is null, it means it&#39;s always enabled

- if parent action is trigger_type workflow, it means it&#39;s enabled when its parent workflow is enabled.
  -&gt; ::enable it after starting the workflow, i.e. executing the initial action
  -&gt; will it stay enabled?
  -&gt; it will get disabled automatically by cascading delete when its parent is deleted

- if parent action is trigger_type parallel, it has no meaning, all the parent&#39;s children will get enabled, anyway

- if parent action is trigger_type dynamic, same shit, no semantics


How about the state_changed_handler only deals with state change at a particular parent_enabled_action_id level?


</pre>
<h2><a name="trigger-conditions" id="trigger-conditions">Trigger
Conditions</a></h2>
<h3>Requirements</h3>
<p>If any change to any child workflow of a case attempts to
trigger the parent action, the trigger condition would tell us
whether to allow the trigger to go through.</p>
<p>The trigger condition could check to see if all child cases are
completed, or it could check if there&#39;s enough to determine the
outcome, e.g. a 2/3 approval.</p>

XXXXXXXXXXXXXXX
<h4>Child Case State Changed Logic</h4>

&gt; We execute the OnChildCaseStateChange callback, if any. This
gets to determine whether the parent action is now complete and
should fire.
<p>We provide a default implementation, which simply checks if the
child cases are in the 'complete' state, and if so,
fires.</p>
<p>NOTE: What do we do if any of the child cases are canceled?
Consider the complete and move on with the parent workflow? Cancel
the parent workflow?</p>
<p>NOTE: Should we provide this as internal workflow logic or as a
default callback implementation? If we leave this as a service
contract with a default implementation, then applications can
customize. But would that ever be relevant? Maybe this callback is
never needed.</p>
<h2><a name="case-state" id="case-state">Case State</a></h2>
<h3>Requirements</h3>
<ul>
<li>We want to be able to suspend a case, to reopen it later,
without having to create an explicit state in the workflow for
this. Suspending the case means it doesn&#39;t show up on
people&#39;s task lists or in reminder emails until it&#39;s
un-suspended.</li><li>In the UI, we want to be able to distinguish between cases that
are considered active and complete, even if the closed ones could
be reopened to haunt us later. A good example is bug-tracker, where
bugs in "open" or "resolved" states are
considered active and should be counted as bugs needing attention,
whereas those in "closed" state are complete and do
not.</li><li>A case can be canceled, which is the same as suspended, except
it doesn&#39;t resurface unless someone actively goes reopen
it.</li><li>Child cases must be locked down so they cannot be reactivated
when the parent workflow has moved on to some other state.</li>
</ul>
<h3>Design</h3>
<pre>
create table workflow_cases(
  ...
  state                     char(40)
                            constraint workflow_cases_state_ck
                            check (state in ('active', 'completed',
                            'canceled', 'suspended'))
                            default 'active',
  locked_p                  boolean default 'f',
  suspended_until           timestamptz,
  ...
);
</pre>
<p>Cases can be active, complete, suspended, or canceled.</p>
<p>They start out as active. For FSMs, when they hit a state with
<code>complete_p = t</code>, the case is moved to
'complete'.</p>
<p>Users can choose to cancel or suspend a case. When suspending,
they can type in a date, on which the case will spring back to
'active' life.</p>
<p>When a parent worfklow completes an action with a sub-workflow,
the child cases that are 'completed' are marked
'closed', and the child cases that are 'active' are
marked 'canceled'.</p>
<p>The difference between 'completed' and 'closed'
is that completed does not prevent the workflow from continuing
(e.g. bug-tracker 'closed' state doesn&#39;t mean that it
cannot be reopened), whereas a closed case cannot be reactivarted
(terminology confusion alert!).</p>
<h2><a name="conditional-transformation" id="conditional-transformation">Conditional Transformation For Atomic
Actions</a></h2>
<pre>
create table workflow_action_fsm_output_map(
  action_id                 integer
                            not null
                            references workflow_actions(action_id)
                            on delete cascade,
  output_short_name         varchar(100),
  new_state                 integer
                            references workflow_fsm_states,
  constraint ...
  primary key (action_id, output_value)
);
</pre>
<p>Callback: <strong>Action.OnFire -&gt; (output)</strong>:
Executed when the action fires. Output can be used to determine the
new state of the case (see below).</p>
<p>The callback must enumerate all the values it can possible
output (similar contruct to GetObjectType operation on other
current workflow service contracts), and the callback itself must
return one of those possible values.</p>
<p>The workflow engine will then allow the workflow designer to map
these possible output values of the callback to new states, in the
case of an FSM, or similar relevant state changes for other
models.</p>
<h3>Service Contract</h3>
<pre>
<strong>workflow.Action_OnFire:</strong>
  OnFire -&gt; string
  GetObjectType -&gt; string
  GetOutputs -&gt; [string]
</pre>
<p>GetOutputs returns a list of short_names and pretty_names
(possibly localizable, with <span>#</span>...# notation) of
possible outputs.</p>
<h3>Note</h3>
<p>The above table could be merged with the current
workflow_fsm_actions table, which only contains one possible new
state, with a null output_short_name.</p>
<h2><a name="conditional-child" id="conditional-child">Conditional
Transformation Based on Child Workflows</a></h2>
<pre>
create table workflow_outcomes(
  outcome_id                integer
                            constraint ...
                            primary key,
  workflow_id               integer
                            constraint wf_outcomes_wf_fk
                            references workflows(workflow_id),
  short_name                varchar(100)
                            constraint wf_outcomes_short_name_nn
                            not null,
  pretty_name               varchar(200)
                            constraint wf_outcomes_pretty_name_nn
                            not null
);

create table workflow_fsm_states(
  ...
  -- If this is non-null, it implies that the case has completed with
  -- the given output, for use in determining the parent workflow&#39;s
  -- new state
  outcome                   integer
                            constraint
                            references workflow_outcomes(outcome_id),
  ...
);

</pre>
<h2><a name="gated-actions" id="gated-actions">Gated
Actions</a></h2>
<h3>Requirements</h3>
<p>An action does not become available until a given list of other
actions have completed. The advanced version is that you can also
specify for each of these other tasks how many times they
must&#39;ve been executed.</p>
<p>Also, an action can at most be executed a certain number of
times.</p>
<h3>Design</h3>
<pre>
create table workflow_action_dependencies(
  action_id                 integer
                            constraint wf_action_dep_action_fk
                            references workflow_actions(action_id),
  dependent_on_action       integer
                            constraint wf_action_dep_dep_action_fk
                            references workflow_actions(action_id),
  min_n                     integer default 1,
  max_n                     integer,
  constraint wf_action_dep_act_dep_pk
  primary key (action_id, dependent_on_action)
);
</pre>
<p>When an action is about to be enabled, and before calling the
CanEnableP callback, we check the workflow_case_enabled_actions
table to see that the required actions have the required number of
rows in the workflow_case_enabled_actions table with enabled_state
'completed'.</p>
<p>The second part, about maximum number of times an action can be
executed, this could be solved with a row in the above table with
the action being dependent upon it self with the given max_n
value.</p>
<h2><a name="enable-callback" id="enable-callback">Enable Condition
Callback</a></h2>
<p>
<strong>Action.CanEnableP -&gt; (CanEnabledP)</strong>: Gets
called when an action is about to be enabled, and can be used to
prevent the action from actually being enabled.</p>
<p>Is called after all database-driven enable preconditions have
been met, i.e. FSM enabled-in-state, and "gated
on"-conditions.</p>
<p>This will only get called once per case state change, so if the
callback refuses to let the action become enabled, it will not be
asked again until the next time an action is executed.</p>
<p>If the callback returns false, the <code>enabled_state</code> of
the row in <code>workflow_case_enabled_actions</code> will be set
to 'refused' (NOTE: Or the row will be deleted?).</p>
<h2><a name="non-user-trigger" id="non-user-trigger">Non-User
Triggered Actions</a></h2>
<h3>Requirements</h3>
<p>Some actions, for example those will child workflows, may not
want to allow users to trigger them.</p>
<h3>Design</h3>
<pre>
create table workflow_actions(
  ...
  user_trigger_p          boolean default 't',
  ...
);
</pre>
<p>If user_trigger_p is false, we do not show the action on any
user&#39;s task list.</p>
<h2><a name="resolution-codes" id="resolution-codes">Resolution
Codes</a></h2>
<h3>Requirements</h3>
<p>The bug-tracker has resolution codes under the
"Resolve" action. It would be useful if these could be
customized.</p>
<p>In addition, I saw one other dynamic-workflow product
(TrackStudio) on the web, and they have the concept of resolution
codes included. That made me realize that this is generally
useful.</p>
<p>In general, a resolution code is a way of distinguishing
different states, even though those states are identical in terms
of the workflow process.</p>
<p>Currently, the code to make these happen is fairly clumsy, what
with the "FormatLogTitle" callback which we invented.</p>
<h3>Design</h3>
<pre>
create sequence ...

create table workflow_action_resolutions(
  resolution_id           integer 
                          constraint wf_act_res_pk
                          primary key,
  action_id               integer
                          constraint wf_act_res_action_fk
                          references workflow_actions(action_id)
                          on delete cascade,
  sort_order              integer
                          constraint wf_act_res_sort_order_nn
                          not null,
  short_name              varchar(100)
                          constraint wf_act_res_short_name_nn
                          not null,
  pretty_name             varchar(200)
                          constraint wf_act_res_pretty_name_nn
                          not null
);

create index workflow_act_res_act_idx on workflow_action_resolutions(action_id);

create table workflow_action_res_output_map(
  action_id               integer
                          not null
                          references workflow_actions(action_id)
                          on delete cascade,
  acs_sc_impl_id          integer
                          not null
                          references acs_sc_impls(impl_id)
                          on delete cascade,
  output_value            varchar(4000),
  resolution_id           integer
                          not null
                          references workflow_action_resolutions(resolution_id)
                          on delete cascade,
);

-- FK index on action_id
-- FK index on acs_sc_impl_id
-- FK index on resolution
</pre>
<h2><a name="assignment-notif" id="assignment-notif">Assignment
Notifications</a></h2>
<h3>Requirements</h3>
<p>When someone is assigned to an action, we want the notification
email to say "You are now assigned to these tasks".</p>
<h3>Design</h3>
<p>We&#39;d need to postpone the notifications until we have fully
updated the workflow state to reflect the changed state, to
determine who should get the normal notifications, and who should
get personalized ones.</p>
<p>Notifications doesn&#39;t support personalized notifications,
but we could use acs-mail/acs-mail-lite to send them out instead,
and exclude them from the normal notifications if they have instant
notifications set up.</p>
<h2><a name="assignment-reminder" id="assignment-reminder">Assignment Reminders</a></h2>
<h3>Requirements</h3>
<p>We want to periodically send out email reminders with a list of
actions the user is assigned to, asking them to come do something
about it. There should be a link to a web page showing all these
actions.</p>
<p>For each action we will list the action pretty-name, the name of
the case object, the date it was enabled, the deadline, and a link
to the action page, where they can do something about it.</p>
<h2><a name="trying-to-sum-up" id="trying-to-sum-up">Trying to Sum
Up</a></h2>
<h4>Logic to Determine if Action is Enabled</h4>
<p>Executed when any action in the workflow has been executed, to
determine which actions are now enabled.</p>
<ul>
<li>If there are any rows in workflow_case_enabled_actions for this
case with enabled_state 'running', no actions can be
enabled, the action is not enabled.</li><li>Is the model-specific precondition met, e.g. are we in one of
the action&#39;s enabled-in states? If not, the action is not
enabled.</li><li>Are other preconditions met, e.g. if the action is gated on
other actions having executed a minimum number of times, or itself
having executed a maximum number fo times? If not, the action is
not enabled.</li><li>Execute the CanEnableP callback. If it returns false, the
action is not enabled.</li><li>The action is enabled.</li>
</ul>
<p>If the action is enabled:</p>
<ul>
<li>If there are any rows in workflow_case_enabled_actions for this
action with enabled_state of 'enabled', the action was
already enabled before. Quit.</li><li>Otherwise start the "Enabled Action Logic"
below.</li>
</ul>
<p>If the action is not enabled.</p>
<ul><li>If there are any rows in workflow_case_enabled_actions for this
action with enabled_state of 'enabled', the action was
enabled before. Update the row to set 'enabled_state' to
'canceled'.</li></ul>
<h4>Enabled Action Logic</h4>
<p>Executed when an action which was previously not enabled becomes
enabled.</p>
<ol>
<li>Insert a row into workflow_case_enabled_actions with
enabled_state = 'enabled', with the proper fire_timestamp:
timeout = null -&gt; fire_timestamp = nul; timeout = 0 -&gt;
fire_timestamp = current_timestamp; timeout &gt; 0 -&gt;
fire_timestamp = current_timestamp + timeout.</li><li>If the action has a timeout of 0, then call
workflow::case::action::execute and quit.</li><li style="list-style: none">
<h4>Un-Enabled Action Logic</h4><p>Executed when an action which was previously enabled is no
longer enabled, because the workflow&#39;s state was changed by
some other action.</p><ol><li>If the action has any child cases, these will be marked
canceled.</li></ol><h4>Action Execute Logic</h4><p>Executed when an enabled action is triggered.</p><ul>
<li style="list-style: none">XXXXXXXXXXXXXXXXXXXXXXX</li><li>If the action has non-null child_workflow, create child cases.
For each role which has a mapping_type of 'per_member' or
'per_user', create one case per member/user of that role.
If more roles have per_member/per_user setting, then the cartesian
product of child cases are created (DESIGN QUESTION: Would this
ever be relevant?)</li><li>If there is any ActionEnabled callback, execute that (only the
first, if multiple exists), and use the workflow_fsm_output_map to
determine which new state to bump the workflow to, if any.</li>
</ul>
</li>
</ol>
<h4>Child Case State Changed Logic</h4>
<p>We execute the OnChildCaseStateChange callback, if any. This
gets to determine whether the parent action is now complete and
should fire.</p>
<p>We provide a default implementation, which simply checks if the
child cases are in the 'complete' state, and if so,
fires.</p>
<p>NOTE: What do we do if any of the child cases are canceled?
Consider the complete and move on with the parent workflow? Cancel
the parent workflow?</p>
<p>NOTE: Should we provide this as internal workflow logic or as a
default callback implementation? If we leave this as a service
contract with a default implementation, then applications can
customize. But would that ever be relevant? Maybe this callback is
never needed.</p>
<h4>On Fire Logic</h4>
<p>When the action finally fires.</p>
<p>If there&#39;s any OnFire callback defined, we execute this.</p>
<p>If the callback has output values defined, we use the mappings
in <code>workflow_action_fsm_output_map</code> to determine which
state to move to.</p>
<p>After firing, we execute the SideEffect callbacks and send off
notifications.</p>
<p>DESIGN QUESTION: How do we handle notifications for child cases?
We should consider the child case part of the parent in terms of
notifications, so when a child action executes, we notify those who
have requested notifications on the parent. And when the last child
case completes, which will also complete the parent action, we
should avoid sending out duplicate notifications. How?</p>
<h4>Callback Types</h4>
<ul>
<li style="color: gray;">(Not needed) <strong>Action.OnEnable -&gt;
(output)</strong>: Gets called when an action is enabled. Output
can be used to determine the new state of the case (see below), in
particular for an in-progress state.</li><li style="color: gray;">(Not needed)
<strong>Action.OnUnEnable</strong>: Gets called when an action that
used to be enabled is no longer enabled. Is not called when the
action fires.</li><li style="color: gray;">(Not needed)
<strong>Action.OnChildCaseStateChange -&gt; (output,
CompleteP)</strong>: Called when a child changes its case state
(active/completed/canceled/suspended). Returns whether the parent
action has now completed. Output can be used to determine the new
state of the case (see below).</li>
</ul>
<h2><a name="timers" id="timers">Timers (Implemented)</a></h2>
<h3>Requirements</h3>
<p>Use cases:</p>
<ul>
<li>A student has one week to send a document to another role. If
he/she fails to do so, a default action executes.</li><li>An OpenACS OCT member has one week to vote on a TIP. If he/she
does not vote within that week, a default "Abstain"
action is executed.</li>
</ul>
<p>The timer will always be of the form "This action will
automatically execute x amount of time after it becomes
enabled". If it is later un-enabled (disabled) because another
action (e.g. a vote action in the second use casae above) was
executed, then the timer will be reset. If the action later becomes
enabled, the timer will start anew.</p>
<h3>Design</h3>
<p>We currently do not have any information on which actions are
enabled, and when they&#39;re enabled. We will probably need a
table, perhaps one just for timed actions, in which a row is
created when a timed action is enabled, and the row is deleted
again when the state changes.</p>
<h4>Extending workflow_actions</h4>
<pre>
create table workflow_actions(
    ...
    -- The number of seconds after having become enabled the action
    -- will automatically execute
    timeout                 interval
    ...
);
</pre>
<p>DESIGN NOTE: The 'interval' datatype is not supported in
Oracle.</p>
<h4>The Enabled Actions Table</h4>
<pre>
create table workflow_case_enabled_actions(
    case_id                 integer
                            constraint wf_case_enbl_act_case_id_nn
                            not null
                            constraint wf_case_enbl_act_case_id_fk
                            references workflow_cases(case_id)
                            on delete cascade,
    action_id               integer
                            constraint wf_case_enbl_act_action_id_nn
                            not null
                            constraint wf_case_enbl_act_action_id_fk
                            references workflow_actions(action_id)
                            on delete cascade,
    -- the timestamp when this action will fires
    execution_time          timestamptz
                            constraint wf_case_enbl_act_timeout_nn
                            not null,
    constraint workflow_case_enabled_actions_pk
    primary key (case_id, action_id)
);
</pre>
<h4>The Logic</h4>
<p>After executing an action,
<code>workflow::case::action::execute</code> will:</p>
<ol>
<li>Delete all actions from
<code>worklfow_case_enabled_actions</code> which are no longer
enabled.</li><li>If the timeout is zero, execute immediately.</li><li>Insert a row for all enabled actions with timeouts which are
not already in <code>workflow_case_enabled_actions</code>, with
<code>fire_timestamp = current_timestamp +
workflow_actions.timeout_seconds</code> .</li>
</ol>
<p>NOTE: We need to keep running, so if another automatic action
becomes enabled after this action fires, they&#39;ll fire as
well.</p>
<h4>The Sweeper</h4>
<p>The sweeper will find rows in
<code>workflow_case_enabled_actions</code> with
<code>fire_timetsamp &lt; current_timestamp</code>, ordered by
fire_timstamp, and execute them.</p>
<p>It should do a query to find the action to fire first, then
release the db-handle and execute it. Then do a fresh query to find
the next, etc. That way we will handle the situation correctly
where the first action firing causes the second action to no longer
be enabled.</p>
<h4>The Optimization</h4>
<p>Every time the sweeper runs, at least one DB query will be made,
even if there are no timed actions to be executed.</p>
<p>Possible optimizations:</p>
<ul><li>We keep an NSV with the timestamp (in [clock seconds] format)
and (case_id, action_id) of the first action to fire. That way, the
sweeper need not hit the DB at all most of the time. When a new
timed action is inserted, we compare with the NSV, and update if
the new action fires before the old action. When the timed action
referred to in the NSV is either deleted because it gets
un-enabled, or executed, we&#39;ll clear the NSV, causing the next
hit to the sweeper to execute the query to find the (case_id,
action_id, fire_timestamp) of the first action to fire. Finally, we
would need an NSV value to represent the fact that there are no
rows in this table, so we don&#39;t keep executing the query in
that case.</li></ul>
<hr>
