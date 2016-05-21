# Cosmos

<img src="https://rawgit.com/shuaibiyy/cosmos/master/cosmos.png" width="100" align="right"/>

This project uses [AWS Lambda](https://aws.amazon.com/lambda/), [API Gateway](https://aws.amazon.com/api-gateway/) and [DynamoDB](https://aws.amazon.com/dynamodb/) to create an API endpoint that can be used to generate a `haproxy.cfg` file based on the parameters provided.

One major pain point of using Lambda and API Gateway is the difficulty of setting things up. This project uses Terraform to ease that difficulty.

You need to have [Terraform](https://www.terraform.io/) installed and a functioning [AWS](https://aws.amazon.com/) account to deploy this project.

## Setup

Follow these steps to deploy:

1. Install NPM modules: `npm install --production`
2. Compress the project: `zip -r cosmos.zip .`.
3. Deploy the project by simply invoking `terraform apply`. You'll be asked for your AWS credentials. If you don't want to be prompted, you can add your credentials to the `variables.tf` file or run the setup using:
```bash
$> terraform apply -var 'aws_access_key={your_aws_access_key}' \
   -var 'aws_secret_key={your_aws_secret_key}'
```

To tear down:
```bash
$> terraform destroy
```

You can find the Invoke URL for Cosmos endpoint via the API Gateway service's console. The steps look like: `Amazon API Gateway | APIs > cosmos > Stages > api`.

## Usage

Cosmos was written to fulfill the deployment architecture described here: [HAProxy Configuration Management with Cosmos and Cosmonaut](https://callme.ninja/haproxy-config-mgmt-cosmos-cosmonaut/).

[Cosmonaut](https://github.com/shuaibiyy/cosmonaut) is a process that can listen to events from a docker daemon, retrieve a HAProxy configuration from Cosmos based on the services running on its host, and use it to reload its host's HAProxy container.

You can generate the config file by running these commands:
```bash
$> curl -o /tmp/haproxycfg -H "Content-Type: application/json" --data @sample-data/data.json <invoke_url>/generate
$> echo "$(</tmp/haproxycfg)" > haproxy.cfg
$> rm /tmp/haproxycfg
```

### Running Locally

You can run Lambda functions locally using [Lambda-local](https://github.com/ashiina/lambda-local) with a command like:
```bash
$> lambda-local -l index.js -h handler -e sample-data/data.js
```

### Running Tests

```
$> npm test
```

### Customizing the Project

The Lambda handler expects an `event` with the structure documented in `index.js`. The [Nunjucks](https://github.com/mozilla/nunjucks) template file (`template/haproxy.cfg.njk`) relies on event structure to interpolate values in the right places. You can pass in any `event` structure you want as long as you modify the Nunjucks template file to understand it.

## Notes

There is a [known issue](https://forums.aws.amazon.com/message.jspa?messageID=678324) whereby a newly deployed API Gateway would fail to call a Lambda function throwing an error similar to this one:
```bash
Execution failed due to configuration error: Invalid permissions on Lambda function
Method completed with status: 500
```
Or:
```bash
{
  "message": "Internal server error"
}
```
The solution for this is straightforward and demonstrated in [this youtube video](https://www.youtube.com/watch?v=H4LM_jw5zzs).
