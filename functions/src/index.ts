import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin SDK before any callable handlers are invoked.
initializeApp();

export { translateChunk, pretranslateBook } from "./translate";
