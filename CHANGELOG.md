# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-06-02

### Added

- Profile: delete all user data
- Classify: travel provider options for the travel category
- UI: transaction and classify screen overhaul
- Dashboard: period navigation and charts
- Dashboard: tap category rows to view period transactions
- UI: payment source picker, Gemini status, and original SMS sheet
- Learning: teach payment source and merchant hints from classify

### Changed

- Docs: Eventarc IAM recovery notes for `notifyClassification` deploy

### Fixed

- Classify: track LLM outcomes and rematch on sync drain
- Dashboard: wire payment sources and improve classify UX
- Classify: re-run LLM backlog and surface Gemini errors
- Categories: remove food default bias and expand category set
- Parse: match payment sources by last4 from Indian bank SMS
- Unmatched drill-down, delete persistence, and payment-source matching
- Dashboard: consolidate unmatched rows and add transaction exclude/delete
