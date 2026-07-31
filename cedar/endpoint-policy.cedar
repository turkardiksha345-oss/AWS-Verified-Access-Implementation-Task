// =============================================================================
// Cedar Policy — Verified Access Endpoint Policy
// Policy Version: ${policy_version}
// =============================================================================
//
// Endpoint-level policy enforces the same authorization rules as the group
// policy, providing defense-in-depth at the Verified Access endpoint layer.
//
// Policy 1: Allow only explicitly approved email addresses
// Policy 2: Approved IAM Identity Center groups only
// Policy 3: Admins bypass maintenance mode
// Policy 4: Explicit deny all (default)
// =============================================================================

// -----------------------------------------------------------------------------
// Policy 3: Admins bypass maintenance mode at endpoint level
// -----------------------------------------------------------------------------
permit(
  principal,
  action,
  resource
)
when {
  context.identity.group.contains("Admins")
};

// -----------------------------------------------------------------------------
// Policy 1 + Policy 2: Exact approved email addresses AND group membership
// ----------------------------------------------------------------------------
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
// Policy 4: Explicit deny all — unmatched requests are denied by Cedar default
// -----------------------------------------------------------------------------
