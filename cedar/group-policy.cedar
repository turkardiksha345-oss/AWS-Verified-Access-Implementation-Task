permit(
    principal,
    action,
    resource
)
when {
    context.identity.group.contains("Admins")
};

permit(
    principal,
    action,
    resource
)
when {
    (
        context.identity.user.email == "dikshat2403@gmail.com" ||
        context.identity.user.email == "nehalwandhare000@gmail.com" ||
        context.identity.user.email == "prashantagchoudhary2004@gmail.com"
    ) &&
    context.identity.group.contains("VerifiedAccessUsers") &&
    ${maintenance_mode} == false
};
