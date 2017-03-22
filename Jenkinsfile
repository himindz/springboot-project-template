#!/usr/bin/env groovy
import hudson.model.*
import hudson.EnvVars
import java.net.URL
MAVEN_OPTS="-Xmx2048m -Xms1024m -XX:+TieredCompilation -XX:TieredStopAtLevel=1"
err = null
isBuildingPullRequest = false
isLocal = true
proceed = false

def getUser(fie){
    if (fie.causes.size() > 0) {
        def user = fie.causes[0].user
        return user;
    }
}

def info(msg){
    echo "\033[1;33m[Info]   \033[1m ${msg}\033[0m"
}
def error(msg){
    echo "\033[1;31m[Error]   \033[1m ${msg}\033[0m"
}
def success(msg){
    echo "\033[1;32m[Success] \033[1m ${msg}\033[0m"
}

def getPomInfo(){
    pom = readMavenPom file: 'pom.xml'
    artifactId=pom.getArtifactId()
    mavenVersion=pom.getVersion()
    groupId=pom.getGroupId()

}

def getSCMRepoInfo() {
    def gitUrl = scm.getUserRemoteConfigs()[0].getUrl()
    def url = new URL(gitUrl)
    try {
        info("FROM_BRANCH=${FROM_BRANCH} TO_BRANCH=${TO_BRANCH}")
        isBuildingPullRequest = true

    } catch (groovy.lang.MissingPropertyException e) {
        isBuildingPullRequest = false
    }
    isLocal = !(gitUrl.contains("http://") || gitUrl.contains("https://") || gitUrl.contains("ssh://"))
    repo_protocol = url.getProtocol()
    git_branch = scm.getBranches().get(0).getName()
}

def checkOut() {
    info "Checking out code from SCM"
    if (isLocal){
        checkout scm
        return
    }
    if (isBuildingPullRequest){
        info("Building Pull Request")
        checkout changelog: true, poll: true,
                scm: [$class: 'GitSCM', branches: [[name: "${FROM_BRANCH}"]],
                      doGenerateSubmoduleConfigurations: false,
                      extensions: [[$class: 'PreBuildMerge',
                                    options: [fastForwardMode: 'FF', mergeRemote: 'origin',  mergeTarget: "${TO_BRANCH}"]],
                                   [$class: 'DisableRemotePoll'], [$class: 'WipeWorkspace']], submoduleCfg: [],
                      userRemoteConfigs: [[credentialsId: "${jenkinsCIYml.git.credentialsId}", url: "${jenkinsCIYml.git.url}"]]]
        info "Merged ${FROM_BRANCH} with ${TO_BRANCH}"
        unstash 'source'


        return;
    }
    info "Running CI Pipeline"
    git url: "${jenkinsCIYml.git.url}" , branch: "${jenkinsCIYml.git.branch}", credentialsId: "${jenkinsCIYml.git.credentialsId}"
    def url = new URL(jenkinsCIYml.git.url)
    repo_url = url.getPort() > 0 ? url.getHost() + ":" + url.getPort() + url.getPath() : url.getHost() + url.getPath()
    vagrantYml=readYaml file:"vagrant.yml"
    unstash 'source'



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
    if (matcher[0]){
        def original = matcher[0]
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
    artifactNewRepo = "default['"+artifactId+"']['repo']='${jenkinsCIYml.nexus.url}/"+groupId.replaceAll("\\.","/")+"/'"
    populateEnv();
    withEnv(["ATTRIBUTESFILE=${attributesFile}"]){
        sh( script: '''
            sed -i "/$artifactRepo/d" $ATTRIBUTESFILE
            sed -i "s/$oldArtifactVersion/$artifactVersion/" $ATTRIBUTESFILE
            echo $artifactNewRepo >> $ATTRIBUTESFILE
            sed -i "s/$cookbookVersion/$cookbookNewVersion/" $metadataFile
        ''', returnStatus:true)
    }

}
def uploadCookbook(){
    info "uploading cookbook "
    failed = sh(script: '''       
        cd chef/cookbooks/$artifactId
        berks install
        berks upload --ssl-verify=false
    ''',returnStatus: true) != 0
    if (failed){
        currentBuild.result = 'FAILURE'
    }
}
def build(){
    info "Building with 'clean compile'"
    withEnv(["MAVEN_OPTS=${MAVEN_OPTS}"]) {
        def failed = sh(script: '''
        mvn -q -B -f pom.xml clean compile -Dmaven.test.skip=true
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
    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'git-user-credentials', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
        sh('git push --force ${repo_protocol}://${GIT_USERNAME}:${GIT_PASSWORD}@${repo_url} ')
    }
}
def pushTagsToGit(){
    withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'git-user-credentials', usernameVariable: 'GIT_USERNAME', passwordVariable: 'GIT_PASSWORD']]) {
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
    withEnv(["NEXUS_URL=${jenkinsCIYml.nexus.url}","VERSTION_TO_RELEASE=${versionNumber}","USER_EMAIL=${jenkinsCIYml.user.email}",
             "USER_NAME=${jenkinsCIYml.user.fullname}","REPO_ID=${jenkinsCIYml.nexus.repo_id}"]){
        sh (script: '''
            mvn -q versions:set -DnewVersion=$VERSTION_TO_RELEASE -DgenerateBackupPoms=false
            git add pom.xml
            git status
            git config --global user.email $USER_EMAIL
            git config --global user.name $USER_NAME
            git commit -a -m "Bumped version number to $VERSTION_TO_RELEASE"
            git status
            git tag -f -a release-$VERSTION_TO_RELEASE -m "Version $VERSTION_TO_RELEASE"
            mvn  -q deploy --global-settings ./projects/${PROJECT_NAME}/${REPO_NAME}/m2_settings.xml -DaltReleaseDeploymentRepository=$REPO_ID::default::$NEXUS_URL -Dmaven.test.skip=true
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
        def user = getUser(fie)
        if ('SYSTEM' == user.toString()) { // SYSTEM means timeout.
            timedOut = true
            currentBuild.result = "ABORTED"
        } else {
            aborted = true
            error "Aborted by: [${user}]"
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
                    getSCMRepoInfo()
                    if (!isLocal){
                        error "checking out"
                        checkout scm
                        def files = findFiles(glob: "projects/${PROJECT_NAME}/${REPO_NAME}/jenkinsci.yml")
                        if (files.size() >0) {
                            try {
                                jenkinsCIYml = readYaml file: "projects/${PROJECT_NAME}/${REPO_NAME}/jenkinsci.yml"
                                stash excludes: '**/target', includes: '**', name: 'source'

                            } catch (err) {
                                error "No Jenkins CI configuration found in ./projects/${PROJECT_NAME}/${REPO_NAME}/jenkinsci.yml"
                                currentBuild.result = "FAILURE"
                                throw err
                            }
                        }else{
                            sh "mkdir ./projects/${PROJECT_NAME}/${REPO_NAME} && cp -R /var/jenkins_home/jenkinsci/* ./projects/${PROJECT_NAME}/${REPO_NAME}/."
                            stash excludes: '**/target', includes: '**', name: 'source'
                        }
                    }

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
                    if (!(isLocal || isBuildingPullRequest)) {
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
