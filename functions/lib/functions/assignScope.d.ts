interface ScopeData {
    campusIds?: string[];
    stageIds?: string[];
    classIds?: string[];
    subjectIds?: string[];
    academicYearIds?: string[];
    studentIds?: string[];
}
interface AssignScopeData {
    targetUserId: string;
    scope: ScopeData;
    organizationId: string;
}
export declare const assignScope: import("firebase-functions/v2/https").CallableFunction<AssignScopeData, Promise<{
    success: boolean;
    targetUserId: string;
    scope: ScopeData;
}>, unknown>;
export {};
