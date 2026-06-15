interface SyncClaimsData {
    targetUserId?: string;
}
export declare const syncClaims: import("firebase-functions/v2/https").CallableFunction<SyncClaimsData, Promise<{
    success: boolean;
    targetUserId: string;
    role: any;
    organizationId: any;
    scopeAccessLevel: string | undefined;
}>, unknown>;
export {};
