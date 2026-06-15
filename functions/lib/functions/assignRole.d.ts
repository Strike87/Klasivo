interface AssignRoleData {
    targetUserId: string;
    newRole: string;
    organizationId: string;
}
export declare const assignRole: import("firebase-functions/v2/https").CallableFunction<AssignRoleData, Promise<{
    success: boolean;
    targetUserId: string;
    oldRole: any;
    newRole: string;
    scopeAccessLevel: string | undefined;
}>, unknown>;
export {};
