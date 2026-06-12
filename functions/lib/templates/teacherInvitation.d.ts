interface InvitationParams {
    teacherName: string;
    schoolName: string;
    inviterName: string;
    inviteCode: string;
    orgId: string;
}
export declare function buildTeacherInvitationHtml(params: InvitationParams): string;
export {};
