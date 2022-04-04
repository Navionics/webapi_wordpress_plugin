final MACHINE_LABEL = 'docker-masxpb'
final GIT_REPO = 'git@github.com:Navionics/webapi_wordpress_plugin.git'

def getRepoURL() {
    sh "git config --get remote.origin.url > .git/remote-url"
    return readFile(".git/remote-url").trim()
}

def getCommitSha() {
  sh "git rev-parse HEAD > .git/current-commit"
  return readFile(".git/current-commit").trim()
}

def updateGithubCommitStatus(description) {
    // workaround https://issues.jenkins-ci.org/browse/JENKINS-38674
    repoUrl = getRepoURL()
    commitSha = getCommitSha()

    step([
            $class: 'GitHubCommitStatusSetter',
            reposSource: [$class: "ManuallyEnteredRepositorySource", url: repoUrl],
            commitShaSource: [$class: "ManuallyEnteredShaSource", sha: commitSha],
            errorHandlers: [[$class: 'ShallowAnyErrorHandler']],
            statusResultSource: [
                    $class: 'ConditionalStatusResultSource',
                    results: [
                            [$class: 'BetterThanOrEqualBuildResult', result: 'SUCCESS', state: 'SUCCESS', message: description],
                            [$class: 'BetterThanOrEqualBuildResult', result: 'UNSTABLE', state: 'SUCCESS', message: description],
                            [$class: 'BetterThanOrEqualBuildResult', result: 'FAILURE', state: 'FAILURE', message: description],
                            [$class: 'AnyBuildResult', state: 'FAILURE', message: 'Loophole']
                    ]
            ]
    ])
}

pipeline {
    agent {
        label MACHINE_LABEL
    }
    parameters {
        gitParameter name: 'BRANCH_NAME',
                type: 'PT_BRANCH',
                branchFilter: 'origin/(.*)',
                defaultValue: 'master',
                selectedValue: 'DEFAULT',
                sortMode: 'DESCENDING_SMART',
                listSize: '15',
                quickFilterEnabled: true,
                description: 'Select your branch'
    }
    options {
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds()
    }
    triggers { pollSCM('H 5 * * 7') }
    environment {
        VERACODE_APP_NAME="ENG-Navionics"
        VERACODE_SANDBOX_NAME="php-service-sandbox-test"
        VERACODE_SCANAME="webapi-wordpress-plugin-${BUILD_DISPLAY_NAME}"
    }
    stages {
        stage('CleanUp') {
            steps {
                deleteDir()
                cleanWs deleteDirs: true, disableDeferredWipeout: true
                git branch: 'master', credentialsId: '03ce9989-445b-437a-868c-64293e2c1de6', url: GIT_REPO
            }
        }
        stage('Checkout Branch') {
            steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: "${params.BRANCH_NAME}"]],
                          doGenerateSubmoduleConfigurations: false,
                          extensions: [],
                          gitTool: 'Default',
                          submoduleCfg: [],
                          userRemoteConfigs: [
                              [credentialsId: '03ce9989-445b-437a-868c-64293e2c1de6',
                               url          : GIT_REPO]
                          ]
                ])
            }
        }
        stage('Veracode upload') {
            agent {
                dockerfile {
                    args '-v ${PWD}:/workspace -w /workspace --rm'
                    dir './environment/jenkins'
                    filename 'veracode-utility.Dockerfile'
                    label 'docker-masxpb'
                    reuseNode true
                }
            }
            steps {
                withCredentials([
                        usernamePassword(credentialsId: 'ae9684f1-2c8d-40fe-88f3-9b011c088d18', passwordVariable: 'VERACODE_API_KEY', usernameVariable: 'VERACODE_API_ID')
                ])
                {
                    sh 'zip -qr ./webapi-wordpress-plugin.zip ./*'
                    veracode applicationName: "${VERACODE_APP_NAME}", canFailJob: true, createSandbox: true, criticality: "VeryHigh", fileNamePattern: "", replacementPattern: "", sandboxName: "${VERACODE_SANDBOX_NAME}", scanExcludesPattern: "", scanIncludesPattern: "", scanName: "${VERACODE_SCANAME}", teams: "", timeout: 60, uploadIncludesPattern: "webapi-wordpress-plugin.zip", vid: "${VERACODE_API_ID}", vkey: "${VERACODE_API_KEY}", waitForScan: true
                }
            }
        }
    }
    post {
        failure {
            emailext( attachLog: true,
                    compressLog: true,
                    recipientProviders: [culprits()],
                    subject: "[${currentBuild.projectName}] Failed Pipeline: ${currentBuild.fullDisplayName}",
                    body: "Something is wrong with ${env.BUILD_URL} on branch ${params.BRANCH_NAME}, please check the log"
            )
        }
        always {
            updateGithubCommitStatus("Jenkins Job ${BUILD_DISPLAY_NAME} - Result: ${currentBuild.currentResult} ")
            deleteDir()
            cleanWs deleteDirs: true, disableDeferredWipeout: true
        }
    }
}
