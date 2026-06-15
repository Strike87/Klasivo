interface SetPermissionOverridesData {
    targetUserId: string;
    organizationId: string;
    overrides: Record<string, boolean>;
    /** If true, replaces all existing overrides. If false (default), merges. */
    replace?: boolean;
}
export declare const setPermissionOverrides: import("firebase-functions/v2/https").CallableFunction<SetPermissionOverridesData, Promise<{
    success: boolean;
    targetUserId: string;
    overrides: Record<string, boolean>;
    overrideCount: number;
}>, unknown>;
export {};
