import {initializeApp} from "firebase-admin/app";
import {ingestSms} from "./ingestSms";

initializeApp();

export {ingestSms};
