import {initializeApp} from "firebase-admin/app";
import {ingestSms} from "./ingestSms";
import {classifyTransaction} from "./classifyTransaction";
import {notifyClassification} from "./notifyClassification";

initializeApp();

export {ingestSms, classifyTransaction, notifyClassification};
