#!/usr/bin/env groovy
import hudson.model.*
import hudson.EnvVars
import java.net.URL
MAVEN_OPTS="-Xmx2048m -Xms1024m -XX:+TieredCompilation -XX:TieredStopAtLevel=1"
err = null
currentVersion = null
isBuildingPullRequest = false

proceed = false
def getUser(fie){
    if (fie.causes.size() > 0) {
        def user = fie.causes[0].user
        return user;
    }
}

def info(msg){
    echo "\033[1;33m[Info]    \033[0m ${msg}"
}
def error(msg){
    echo "\033[1;31m[Error]   \033[0m ${msg}"
}
def success(msg){
    echo "\033[1;32m[Success] \033[0m ${msg}"
}

def getPomInfo(){
    pom = readMavenPom file: 'pom.xml'
    artifactId=pom.getArtifactId()
    mavenVersion=pom.getVersion()
    groupId=pom.getGroupId()

}

def checkOut() {
    checkout scm
    unstash 'source'
    vagrantYml=readYaml file:"vagrant.yml"
    def gitUrl = scm.getUserRemoteConfigs()[0].getUrl()
    isLocal = true
    git_branch = scm.getBranches().get(0).getName()

    isBuildingPullRequest = true
    try {
        info("FROM_BRANCH=${FROM_BRANCH} TO_BRANCH=${TO_BRANCH}")
    } catch (groovy.lang.MissingPropertyException e) {
        isBuildingPullRequest = false
    }
    if (gitUrl.contains("http://") || gitUrl.contains("https://")){
        isLocal = false
        def url = new URL(gitUrl)
        if (url.getPort() >0){
            repo_url = url.getHost()+":"+url.getPort()+url.getPath()
        }else{
            repo_url = url.getHost()+url.getPath()
        }
        repo_protocol = url.getProtocol()

    }

    if (isBuildingPullRequest){
        info("Building Pull Request")
        checkout changelog: true, poll: true,
                scm: [$class: 'GitSCM', branches: [[name: "${FROM_BRANCH}"]],
                      doGenerateSubmoduleConfigurations: false,
                      extensions: [[$class: 'PreBuildMerge',
                                    options: [fastForwardMode: 'FF', mergeRemote: 'origin',  mergeTarget: "${TO_BRANCH}"]],
                                   [$class: 'DisableRemotePoll'], [$class: 'WipeWorkspace']], submoduleCfg: [],
                      userRemoteConfigs: [[credentialsId: 'git-user-credentials', url: "${gitUrl}"]]]
        info "Merged ${FROM_BRANCH} with ${TO_BRANCH}"
    }

    if (!isLocal && !isBuildingPullRequest){
        info "Running CI Pipeline"
        try {
            jenkinsCIYml=readYaml file:"./jenkinsci/jenkinsci.yml"
            sh 'cat ./jenkinsci/jenkinsci.yml'
            info "URL : "+ jenkinsCIYml.nexus.url

        }catch(err){
            info "No Jenkins CI configuration found in ./jenkinsci/jenkinsci.yml"
            currentBuild.result = "FAILURE"
            throw err
        }

    }
    return isLocal

}
@NonCPS
def populateEnv(){ binding.variables.each{k,v -> env."$k" = "$v"} }
def getBranchName(){
    return git_branch
}
def extractCurrentVersion(forRelease){
    def version = "<version>"+mavenVersion+"</version>"
    def matcher = forRelease ?  version =~ '<version>(.*?)(-SNAPSHOT)*</version>' : version =~ '<version>(.*)</version>'
    matcher[0] ? matcher[0][1] : null
}

def getNextVersion(){
    def version = "<version>"+mavenVersion+"</version>"
    def matcher = version =~ '<version>(\\d*)\\.(\\d*)\\.(\\d*)(-SNAPSHOT)*</version>'
    info matcher[0].toString()
    if (matcher[0]){
        def original = matcher[0]
        info original[3]
        def major = original[1];
        def minor = original[2];
        def patch  = Integer.parseInt(original[3]) + 1;
        def v = "${major}.${minor}.${patch}"
        v ? v : null
    }
}
def updateChefCookbookVersion(oldversion, newversion){
    metadataFile = 'chef/cookbooks/'+artifactId+"/metadata.rb"
    cookbookVersion = "version          '"+oldversion+"'"
    cookbookNewVersion = "version          '"+newversion+"'"

    def attributesFile =  'chef/cookbooks/'+artifactId+'/attributes/default.rb'
    artifactVersion= "default\\['"+artifactId+"'\\]\\['artifact'\\]\\['version'\\] = \""+newversion+"\""
    oldArtifactVersion= "default\\['"+artifactId+"'\\]\\['artifact'\\]\\['version'\\] = \""+oldversion+"\""
    artifactRepo = "default\\['"+artifactId+"'\\]\\['repo'\\]"
    artifactNewRepo = "default['"+artifactId+"']['repo']='"+${jenkinsCIYml.nexus.url}+"/"+groupId+"/'"
    info artifactVersion
    populateEnv();
    withEnv(["ATTRIBUTESFILE=${attributesFile}"]){
        sh( script: '''
            set
            sed -i "/$artifactRepo/d" $ATTRIBUTESFILE
            sed -i "s/$oldArtifactVersion/$artifactVersion/" $ATTRIBUTESFILE
            info $artifactNewRepo >> $ATTRIBUTESFILE
            sed -i "s/$cookbookVersion/$cookbookNewVersion/" $metadataFile

        ''', returnStatus:true)
    }
    def lines = readFile(attributesFile)
    info lines.toString()

}
def uploadCookbook(){
    failed = sh(script: '''
        set
        cd chef/cookbooks
        knife cookbook upload $artifactId
    ''',returnStatus: true) != 0
    if (failed){
        currentBuild.result = 'FAILURE'
    }
}
def build(){
    withEnv(["MAVEN_OPTS=${MAVEN_OPTS}"]) {
        def failed = sh(script: '''
        mvn -q -B -f pom.xml clean compile
        ''', returnStatus: true) != 0;

        if (failed) {
            currentBuild.result = 'FAILURE'
        }
    }
}
def unitTests(){
    withEnv(["MAVEN_OPTS=${MAVEN_OPTS}"]) {
        def failed = sh(script: '''
          mvn -q -f pom.xml verify 
          ''', returnStatus: true) != 0;
        archive '**/*.jar'
        step([$class: 'JUnitResultArchiver', testResults: '**/target/surefire-reports/TEST-*.xml'])
        if (failed) {
            currentBuild.result = 'FAILURE'
        }
    }
}
def staticAnalysis(){
    withEnv(["MAVEN_OPTS=${MAVEN_OPTS}"]) {
        def failed = sh(script: '''
            mvn -X -B -f pom.xml findbugs:check -Dmaven.findbugs.skip=false
            mvn -q -B -f pom.xml pmd:check -Dmaven.pmd.skip=false
            mvn --quiet -B -f pom.xml checkstyle:check -Dmaven.checkstyle.skip=false
            ''', returnStatus: true) != 0

        step([$class: 'PmdPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', pattern: '', shouldDetectModules: true, unHealthy: ''])
        step([$class: 'CheckStylePublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', pattern: '', shouldDetectModules: true, unHealthy: ''])
        step([$class: 'FindBugsPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: '**/findbugsXml.xml', shouldDetectModules: true, unHealthy: ''])
        step([$class: 'AnalysisPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', unHealthy: ''])
        if (failed) {
            currentBuild.result = 'UNSTABLE'
        }
    }
}
def acceptanceTests(currentVersion){

    withEnv(["VERSION_IN_POM=${currentVersion}"]){
        def failed = sh (script:'''
          chmod +x docker/run.sh
          export DOCKER_API_VERSION=1.22
          export APP_IP=172.17.0.1
          info $JAVA_HOME
          mvn verify -Pacceptance-tests
        ''', returnStatus: true) != 0

        if (failed){
            currentBuild.result = 'FAILURE'
        }

    }
    try {
        step([$class: 'CucumberReportPublisher', fileExcludePattern: '', fileIncludePattern: '**/cucumber*.json', ignoreFailedTests: false, jenkinsBasePath: '', jsonReportDirectory: '', missingFails: false, parallelTesting: false, pendingFails: false, skippedFails: false, undefinedFails: false])
    }catch (IllegalStateException e){

    }
}



def pushToGit(){
    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'jenkins_ci_push_credential', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
        sh('git push --force ${repo_protocol}://${GIT_USERNAME}:${GIT_PASSWORD}@${repo_url}  ')
    }
}
def pushTagsToGit(){
    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'jenkins_ci_push_credential', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
        sh('git push --force ${repo_protocol}://${GIT_USERNAME}:${GIT_PASSWORD}@${repo_url}  --tags')
    }
}

def deploy(){
    info "Deploying on Test via Chef"
}
def release(){
    nextVersion = getNextVersion();
    def BRANCH_NAME = getBranchName()
    def failed=false;
    populateEnv()
    error("${jenkinsCIYml.nexus.url}")
    withEnv(["NEXUS_URL=${jenkinsCIYml.nexus.url}","VERSTION_TO_RELEASE=${versionNumber}","USER_EMAIL=${jenkinsCIYml.user.email}",
             "USER_NAME=${jenkinsCIYml.user.fullname}","REPO_ID=${jenkinsCIYml.nexus.repo_id}"]){
        sh (script: '''
            echo $REPO_ID
            echo "Nexus URL: $NEXUS_URL"
            echo "deploy -DaltReleaseDeploymentRepository=$REPO_ID::default::$NEXUS_URL -Dmaven.test.skip=true"
            mvn -q versions:set -DnewVersion=$VERSTION_TO_RELEASE -DgenerateBackupPoms=false
            git add pom.xml
            git status
            git config --global user.email $USER_EMAIL
            git config --global user.name $USER_NAME
            git commit -a -m "Bumped version number to $VERSTION_TO_RELEASE"
            git status
            git tag -f -a release-$VERSTION_TO_RELEASE -m "Version $VERSTION_TO_RELEASE"
            mvn  -q deploy --global-settings ./jenkinsci/settings.xml -DaltReleaseDeploymentRepository=$REPO_ID::default::$NEXUS_URL -Dmaven.test.skip=true
        ''', returnStatus: true) != 0
    }

    uploadCookbook()
    pushToGit()
    pushTagsToGit()
    updateChefCookbookVersion(versionNumber,nextVersion)
    sh '''
        mvn -q versions:set  -DgenerateBackupPoms=false  -DnewVersion=${nextVersion}-SNAPSHOT
        git commit -a -m "Setting next version number to ${nextVersion}-SNAPSHOT"
    '''
    pushToGit()
    currentBuild.displayName = versionNumber
    currentBuild.description = "Released Version "+versionNumber
}
def verifyCookbook(){
    info "Verifying Cookbook"

}
def ask(question,timevalue, timeunit){
    def timedOut = false
    def aborted = false
    try {
        timeout(time: timevalue, unit: timeunit) { // change to a convenient timeout for you
            userInput = input(id: 'Proceed1', message: question, parameters: [])
        }
    } catch (org.jenkinsci.plugins.workflow.steps.FlowInterruptedException fie) {
        // timeout reached or input false
        def user = getUser(fie)
        if ('SYSTEM' == user.toString()) { // SYSTEM means timeout.
            timedOut = true
            currentBuild.result = "ABORTED"
        } else {
            aborted = true
            info "Aborted by: [${user}]"
            currentBuild.result = "ABORTED"
        }


    }
    if (timedOut || aborted){
        return false
    }
    return true;
}
node {
    try {
        wrap([$class: 'AnsiColorBuildWrapper']) {
            try {
                node("master"){
                    sh 'cp -R /var/jenkins_home/jenkinsci ./jenkinsci'
                    stash excludes: '**/target', includes: '**', name: 'source'

                }
                node("jenkins-slave") {
                    stage "\u2776 Checkout"
                    isLocal = checkOut()
                    stage "\u2777 Build"
                    build()
                    stage '\u2778 Unit/Integration Tests'
                    //unitTests()
                    stage '\u2779 Static Analysis'
                    //staticAnalysis()
                    stage '\u277A Acceptance Tests'
                    getPomInfo()
                    versionNumber = extractCurrentVersion(false)
                    //acceptanceTests(versionNumber)
                    if (!isBuildingPullRequest) {
                        stage '\u277B Release'
                        versionNumber = extractCurrentVersion(true)
                        proceed = ask('Release version ' + versionNumber + ' to nexus repository?', 1, "HOURS")
                        if (proceed) {
                            release()
                            stage '\u277D Deploy on Test'
                            def proceed_deploy = ask('Do you want to deploy version ' + versionNumber + ' to Test?', 1, "MINUTES")
                            if (proceed_deploy) {
                                deploy()
                            }
                        }

                    }
                }

            } catch (caughtError) {
                err = caughtError
                currentBuild.result = "FAILURE"
            }
        }
    } finally {
        (currentBuild.result != "ABORTED") && node("master") {
        }
        if (err) {
            throw err
        }
    }
}
