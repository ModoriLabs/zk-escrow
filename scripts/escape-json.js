#!/usr/bin/env node

// Script to properly escape JSON data for fixture files
const data = {
    provider: 'http',
    parameters: '{"method":"GET","responseMatches":[{"type":"regex","value":"<table[^>]*class=\\"table table--vertical-align-top mt-16\\"[^>]*>.*?<tbody[^>]*class=\\"table__tbody-row\\"[^>]*>.*?<tr>.*?(?:<td[^>]*>[^<]*</td>\\\\s*){0}<td[^>]*>(?<transactionDate>[^<]+)</td>"},{"type":"regex","value":"<table[^>]*class=\\"table table--vertical-align-top mt-16\\"[^>]*>.*?<tbody[^>]*class=\\"table__tbody-row\\"[^>]*>.*?<tr>.*?(?:<td[^>]*>[^<]*</td>\\\\s*){1}<td[^>]*>(?<recipientName>[^<]+)</td>"},{"type":"regex","value":"<table[^>]*class=\\"table table--vertical-align-top mt-16\\"[^>]*>.*?<tbody[^>]*class=\\"table__tbody-row\\"[^>]*>.*?<tr>.*?(?:<td[^>]*>[^<]*</td>\\\\s*){3}<td[^>]*>(?<transactionAmount>[^<]+)</td>"},{"type":"regex","value":"<table[^>]*class=\\"table table--vertical-align-top mt-16\\"[^>]*>.*?<tbody[^>]*class=\\"table__tbody-row\\"[^>]*>.*?<tr>.*?(?:<td[^>]*>[^<]*</td>\\\\s*){5}<td[^>]*>(?<receivingBankAccount>[^<]+)</td>"},{"type":"regex","value":"<table[^>]*class=\\"table table--vertical-align-top mt-16\\"[^>]*>.*?<tbody[^>]*class=\\"table__tbody-row\\"[^>]*>.*?<tr>.*?(?:<td[^>]*>[^<]*</td>\\\\s*){6}<td[^>]*>(?<senderNickname>[^<]+)</td>"},{"type":"regex","value":"<h1[^>]*>(?<documentTitle>[^<]+)</h1>"}],"url":"https://api.tossbank.com/api-public/document/view/{{URL_PARAMS_1}}/{{URL_PARAMS_GRD}}"}',
    owner: '0xf9f25d1b846625674901ace47d6313d1ac795265',
    timestampS: 1753414352,
    context: '{"extractedParameters":{"documentTitle":"송금확인증","receivingBankAccount":"100202642943(토스뱅크)","recipientName":"이현민(모임통장)","senderNickname":"anvil-1","transactionAmount":"-13","transactionDate":"2025-07-25 12:27:19"},"providerHash":"0xffb501528259e6d684e1c2153fbbacab453fe9c97c336dc4f8f48d70a0e2a13d"}',
    identifier: '0xfe1819a7dbf9e90718988eaa8fc6bfc3bd8ce60a6aa0fdf237687313283c2795',
    epoch: 1
};

// Create the full fixture structure
const fixture = {
    claimInfo: {
        provider: data.provider,
        parameters: data.parameters,
        context: data.context
    },
    signedClaim: {
        claim: {
            identifier: data.identifier,
            owner: data.owner,
            timestampS: data.timestampS,
            epoch: data.epoch
        },
        signatures: ["de3e16d4b4c50329b7f53743e3adb8c8e60f31a5e9e864304a4a43a04b2db6664982e2d73b9360c3a38778287c0aae7f24b5ae863b50f23c939e4a4e3606dd331c"]
    },
    isAppclipProof: false
};

// Convert to properly escaped JSON
const escapedJson = JSON.stringify(fixture, null, 2);

console.log('Properly escaped JSON:');
console.log(escapedJson);

// Optionally write to file
const fs = require('fs');
const path = require('path');

const outputPath = path.join(__dirname, '..', 'tests', 'fixtures', 'escrow-proof-anvil-fixed.json');
fs.writeFileSync(outputPath, escapedJson);
console.log(`\nJSON written to: ${outputPath}`);
