/**
 * Klasivo — Teacher Invitation Template
 *
 * Sent when a school owner invites a teacher to join
 * their organisation on Klasivo.
 */
export interface TeacherInvitationPayload {
    teacherName: string;
    schoolName: string;
    inviterName: string;
    inviteCode: string;
    orgId: string;
}
/**
 * Build the HTML for a teacher invitation email.
 *
 * @returns Complete HTML string ready for Resend
 */
export declare function buildTeacherInvitation(payload: TeacherInvitationPayload): string;
//# sourceMappingURL=teacherInvitation.d.ts.map