// item descriptions render as HTML ({@html}), sanitized here before ever reaching the DOM
import DOMPurify from 'dompurify';

const ALLOWED_TAGS = ['b', 'i', 'em', 'strong', 'img', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'pre', 'ol', 'ul', 'li', 'p', 'div', 'br'];
const ALLOWED_ATTR = ['src', 'alt', 'height', 'width'];

export function sanitizeHtml(dirty: string): string {
	return DOMPurify.sanitize(dirty, { ALLOWED_TAGS, ALLOWED_ATTR });
}
