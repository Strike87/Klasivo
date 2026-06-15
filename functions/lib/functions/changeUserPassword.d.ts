interface ChangePasswordData {
    currentPassword?: string;
    newPassword: string;
    targetUserId?: string;
}
export declare const changeUserPassword: import("firebase-functions/v2/https").CallableFunction<ChangePasswordData, Promise<{
    success: boolean;
    targetUserId: string;
}>, unknown>;
export {};
