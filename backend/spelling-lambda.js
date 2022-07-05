const { once } = require('events');
const https = require('https');
const AWS = require('aws-sdk');
const s3 = new AWS.S3();
const cloudfront = new AWS.CloudFront();

exports.handler = async (event) => {
    const URL = 'https://www.nytimes.com/puzzles/spelling-bee';
    const [res] = await once(https.get(URL), 'response');
    console.log('Successfully got status code ' + res.statusCode);
    
    let data = '';
    res.on('data', d => { data += d });
    await once(res, 'end');
    console.log('Successfully got all data, len = ' + data.length);
    
    const a = data.indexOf('{"today":');
    if(a < 0) { console.error("can't find beginning"); return }
    const b = data.indexOf('}}', a);
    if(b < 0) { console.error("can't find end"); return; }
    data = data.slice(a, b + 2);
    const print_date = JSON.parse(data).today.printDate;
    console.log('Successfully scraped data for ' + print_date);
   
    const put_resp = await s3.putObject({
        Bucket: process.env.bucket_name,
        Key: 'gamedata',
        Body: data,
        ContentType: 'text/plain'
    }).promise();
    console.log("Successfully PUT gamedata, " + put_resp.toString());
    
    const inv_resp = await cloudfront.createInvalidation({
        DistributionId: process.env.distribution_id,
        InvalidationBatch: {
            CallerReference: 'spelling-fetch-to-s3-' + print_date,
            Paths: {
                Quantity: 1,
                Items: ['/gamedata']
            }
        }
    }).promise();
    console.log("Successfully created invalidation, " + inv_resp.toString());

    console.log('Successfully exiting spelling-fetch-to-s3 for ' + print_date);
};
