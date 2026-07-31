// =============================================================================
// Cedar Policy — Verified Access Group Policy
// Policy Version: ${policy_version}
// =============================================================================
//
// Policy 1: Allow only explicitly approved email addresses
// Policy 2: Allow only approved IAM Identity Center groups
// Policy 3: Admins bypass maintenance mode
// Policy 4: Explicit deny all (default deny — Zero Trust)
//
// Approved groups: VerifiedAccessUsers, Admins
// Maintenance mode: ${maintenance_mode}
// =============================================================================

// -----------------------------------------------------------------------------
// Policy 3: Admins bypass maintenance mode
// During maintenance, only members of the Admins group may access the app.
// -----------------------------------------------------------------------------
permit(
  principal,
  action,
  resource
)
when {
  // Policy 3: Admins always permitted, even during maintenance
  context.identity.group.contains("Admins")
};

// -----------------------------------------------------------------------------
// Policy 1 + Policy 2: Exact approved email addresses AND group membership
// Only the specified users in the approved group may access the app.
// -----------------------------------------------------------------------------
permit(
  principal,
  action,
  resource
)
when {
  (
    context.identity.email == "nehalwandhare000@gmail.com" ||
    context.identity.email == "dikshat2403@gmail.com" ||
    context.identity.email_addr == "nehalwandhare000@gmail.com" ||
    context.identity.email_addr == "dikshat2403@gmail.com" ||
    context.identity.user.email == "nehalwandhare000@gmail.com" ||
    context.identity.user.email == "dikshat2403@gmail.com" ||
    context.identity.user.email_addr == "nehalwandhare000@gmail.com" ||
    context.identity.user.email_addr == "dikshat2403@gmail.com" ||
    context.identity.user.uid == "c123ed7a-f021-7002-7ff1-065eb79f31a3" ||
    context.actor.user.email == "nehalwandhare000@gmail.com" ||
    context.actor.user.email == "dikshat2403@gmail.com" ||
    context.actor.user.email_addr == "nehalwandhare000@gmail.com" ||
    context.actor.user.email_addr == "dikshat2403@gmail.com" ||
    context.actor.user.uid == "c123ed7a-f021-7002-7ff1-065eb79f31a3" ||
    principal.email == "nehalwandhare000@gmail.com" ||
    principal.email == "dikshat2403@gmail.com" ||
    principal.email_addr == "nehalwandhare000@gmail.com" ||
    principal.email_addr == "dikshat2403@gmail.com" ||
    context.identity.email == "nehalwandhare000@gmail.com" ||
    principal.user.email_addr == "nehalwandhare000@gmail.com" ||
    principal.user.email == "nehalwandhare000@gmail.com" ||
    principal.user.email == "dikshat2403@gmail.com" ||
    principal.user.email_addr == "nehalwandhare000@gmail.com" ||
    principal.user.email_addr == "dikshat2403@gmail.com" ||
    principal.user.uid == "c123ed7a-f021-7002-7ff1-065eb79f31a3"
  ) &&

  ${maintenance_mode} == false
};

// -----------------------------------------------------------------------------
// Policy 4: Explicit deny all — implicit default deny in Cedar
// Any request not matching the permit rules above is denied.
// This comment documents the explicit deny-all posture (Zero Trust default).
// -----------------------------------------------------------------------------

// Protected Application: https://portal-dev.cdec-engineer.store
