- name: "CustomCommandDocument"
            action: "aws:runPowerShellScript"
            isCritical: true
            inputs:
              runCommand:
                #- 'try {'
                #- $INSTANCE_ID = (Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/instance-id)
                #- $HOSTNAME = aws ec2 describe-tags --filter Name=resource-id,Values=$INSTANCE_ID --query 'Tags[?Key==`Name`].Value' --output text
                #- $DOCUMENT_NAME = "DL-Command-" + $HOSTNAME
                #- $DOCUMENT_EXISTS = aws ssm list-documents --query "DocumentIdentifiers[?Name=='$DOCUMENT_NAME']"
                #  $acmd=aws ssm list-documents --query DocumentIdentifiers[?Name==``DL-Command-$HOSTNAME``]
                #- $result=$acmd
                #- 'if ($result -eq "[]") {'
                #- echo 'no custom command'
                #- '} else {'
                #- echo 'found custom command document '
                #- aws ssm send-command --instance-ids $INSTANCE_ID --document-name DL-Command-$HOSTNAME
                #- '}'
                #- '}'
                #- 'catch {'
                #- 'exit 99 }'

                $INSTANCE_ID = (Invoke-RestMethod -Method Get -Uri http://169.254.169.254/latest/meta-data/instance-id)
                $HOSTNAME = aws ec2 describe-tags --filter Name=resource-id,Values=$INSTANCE_ID --query 'Tags[?Key==`Name`].Value' --output text
                $DOCUMENT_NAME = "DL-Command-" + $HOSTNAME
                $DOCUMENT_EXISTS = aws ssm list-documents --query "DocumentIdentifiers[?Name=='$DOCUMENT_NAME']"

                function customerror {
                $STACK_NAME = aws ec2 describe-tags --filters Name=resource-id,Values=${INSTANCE_ID} Name=key,Values=aws:cloudformation:stack-name --query "Tags[].Value" --output text
                aws sns publish --topic-arn arn:aws:sns:us-east-1:xxxxxxx:PostConfigSnsTopic --message "Custom PostConfig $DOCUMENT_NAME failed. Please review the Document output." --subject "Custom PostConfig failed"
                }

                function commandrun {
                $COMMAND_ID=aws ssm send-command `
                    --targets "Key=instanceids,Values=$INSTANCE_ID" `
                    --document-name $DOCUMENT_NAME `
                    --output text `
                    --query "Command.CommandId"
                }

                function commandreturn {
                $COMMAND_RETURN=aws ssm list-command-invocations `
                    --command-id $COMMAND_ID `
                    --details `
                    --output text `
                    --query "CommandInvocations[].Status[]"
                }

                function commandcheck {
                #case $COMMAND_RETURN in
                #  Success)
                #    exit 0
                #    ;;
                #  InProgress)
                #   echo "Checking an InProgress Command."
                #   commandreturn
                #   commandcheck && break
                #    ;;
                #  *)
                #    customerror
                #    ;;
                #esac

                switch($COMMAND_RETURN){
                    Success {"exit 0"}
                    InProgess {echo "Checking an InProgress Command."; commandreturn; commandcheck && break }
                    * {customerror}
                  }
                }

                if [[ "$DOCUMENT_EXISTS" == "[]" ]] ; then
                   printf "No custom document $DOCUMENT_NAME exists for this instance.\n"
                  exit 0
                else
                  commandrun
                  commandreturn
                  commandcheck
                fi
              onFailure: exit
            isEnd: false