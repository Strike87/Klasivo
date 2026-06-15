interface AnnouncementParams {
    schoolName: string;
    title: string;
    message: string;
    senderName: string;
    senderRole: string;
    priority: string;
}
export declare function buildSchoolAnnouncementHtml(params: AnnouncementParams): string;
export {};
