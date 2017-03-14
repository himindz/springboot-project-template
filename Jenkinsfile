#!/usr/bin/env groovy
import hudson.model.*
import hudson.EnvVars
import java.net.URL
err = null
currentVersion = null
isBuildingPullRequest = false

def getUser(fie){
    if (fie.causes.size() > 0) {
        def user = fie.causes[0].user
        return user;
    }
}

def getPomInfo(){
    pom = readMavenPom file: 'pom.xml'
    artifactId=pom.getArtifactId()
    mavenVersion=pom.getVersion()
    groupId=pom.getGroupId()
    try{
        nexusRepoUrl=pom.getDistributionManagement().getRepository().getUrl()
    }catch(Exception e){
        println("No Nexus Repo configured!")
    }
}

def checkOut() {
    jenkinsCIYml=readYaml file:"jenkinsci.yml"
    vagrantYml=readYaml file:"vagrant.yml"
    checkout scm
    def gitUrl = scm.getUserRemoteConfigs()[0].getUrl()
    echo "Git URL :" + gitUrl
    isLocal = true
    git_branch = scm.getBranches().get(0).getName()
    sh 'git rev-parse --abbrev-ref HEAD > /tmp/GIT_BRANCH'
    git_branch = readFile('/tmp/GIT_BRANCH').trim()
    echo "Git Branch: "+git_branch
    echo "Checked out branch "+ git_branch
    isBuildingPullRequest = true
    try {
        echo "TO_BRANCH=${TO_BRANCH} , FROM_BRANCH=${FROM_BRANCH}"
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

    if (!isLocal && isBuildingPullRequest){
        echo "Building Pull Request"
        checkout changelog: true, poll: true, scm: [$class: 'GitSCM', branches: [[name: "${git_branch}"]], doGenerateSubmoduleConfigurations: false, extensions: [[$class: 'PreBuildMerge', options: [fastForwardMode: 'FF', mergeRemote: 'origin',  mergeTarget: "${TO_BRANCH}"]], [$class: 'DisableRemotePoll'], [$class: 'WipeWorkspace']], submoduleCfg: [], userRemoteConfigs: [[credentialsId: '8edec322-14b9-4321-b27a-2ebd8b5ea3d3', url: "${gitUrl}"]]]
        echo "Merged ${FROM_BRANCH} with ${git_branch}"
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
    echo matcher[0].toString()
    if (matcher[0]){
        def original = matcher[0]
        echo original[3]
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
    artifactNewRepo = "default['"+artifactId+"']['repo']='"+nexusRepoUrl+"/"+groupId+"/'"
    echo artifactVersion
    populateEnv();
    withEnv(["ATTRIBUTESFILE=${attributesFile}"]){
        sh '''
            ls -ltr
            set
            sed -i "/$artifactRepo/d" $ATTRIBUTESFILE
            sed -i "s/$oldArtifactVersion/$artifactVersion/" $ATTRIBUTESFILE
            echo $artifactNewRepo >> $ATTRIBUTESFILE
            sed -i "s/$cookbookVersion/$cookbookNewVersion/" $metadataFile

        '''
    }
    def lines = readFile(attributesFile)
    echo lines.toString()

}
def uploadCookbook(){
    sh '''
        cd chef/cookbooks
        knife cookbook upload $artifactId
    '''
}
def build(){
    unstash 'source'
    sh '''
        export MAVEN_OPTS="-Xmx2048m -Xms1024m -XX:+TieredCompilation -XX:TieredStopAtLevel=1"
        mvn -q -B -f pom.xml clean compile
    '''
}
def unitTests(){
    sh '''
      export MAVEN_OPTS="-Xmx2048m -Xms1024m -XX:+TieredCompilation -XX:TieredStopAtLevel=1 "
      mvn -q -f pom.xml verify 
    '''
    archive '**/*.jar'
    step([$class: 'JUnitResultArchiver', testResults: '**/target/surefire-reports/TEST-*.xml'])
}
def staticAnalysis(){
    sh '''
      mvn -X -B -f pom.xml findbugs:check -Dmaven.findbugs.skip=false
      mvn -q -B -f pom.xml pmd:check -Dmaven.pmd.skip=false
      mvn --quiet -B -f pom.xml checkstyle:check -Dmaven.checkstyle.skip=false
    '''
    step([$class: 'PmdPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', pattern: '', shouldDetectModules: true, unHealthy: ''])
    step([$class: 'CheckStylePublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', pattern: '', shouldDetectModules: true, unHealthy: ''])
    step([$class: 'FindBugsPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', excludePattern: '', healthy: '', includePattern: '', pattern: '**/findbugsXml.xml', shouldDetectModules: true, unHealthy: ''])
    step([$class: 'AnalysisPublisher', canComputeNew: false, canRunOnFailed: true, defaultEncoding: '', healthy: '', unHealthy: ''])
}
def acceptanceTests(currentVersion){
    withEnv(["VERSION_IN_POM=${currentVersion}"]){
        sh '''
          chmod +x docker/run.sh
          export DOCKER_API_VERSION=1.22
          export APP_IP=172.17.0.1
          echo $JAVA_HOME
          mvn verify -Pacceptance-tests
        '''

    }
    step([$class: 'CucumberReportPublisher', fileExcludePattern: '', fileIncludePattern: '**/cucumber*.json', ignoreFailedTests: false, jenkinsBasePath: '', jsonReportDirectory: '', missingFails: false, parallelTesting: false, pendingFails: false, skippedFails: false, undefinedFails: false])
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
    echo "Deploying on Test via Chef"
}
def release(){
    checkOut()
    nextVersion = getNextVersion();
    def BRANCH_NAME = getBranchName()
    populateEnv()
    withEnv(["VERSTION_TO_RELEASE=${versionNumber}","USER_EMAIL=${jenkinsCIYml.email}","USER_NAME=${jenkinsCIYml.user}"]){
        sh '''
            mvn -q versions:set -DnewVersion=$VERSTION_TO_RELEASE -DgenerateBackupPoms=false
            git add pom.xml
            git status
            git config --global user.email $USER_EMAIL
            git config --global user.name $USER_NAME
            git commit -a -m "Bumped version number to $VERSTION_TO_RELEASE"
            git status
            git tag -f -a release-$VERSTION_TO_RELEASE -m "Version $VERSTION_TO_RELEASE"
        '''
    }
    withEnv(["VERSION_IN_POM=${versionNumber}"]){
        sh '''
            cp /m2/settings*xml /home/jenkins/.m2
            mvn -q  deploy -Dmaven.test.skip=true
        '''
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
    echo "Verifying Cookbook"

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
            currentBuild.result = "FAILED"
        } else {
            aborted = true
            echo "Aborted by: [${user}]"
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
                node("master") {
                    stage "\u2776 Checkout"
                    isLocal = checkOut()
                    stash excludes: '**/target', includes: '**', name: 'source'
                }
                node("jenkins-slave") {
                    stage "\u2777 Build"
                    build()
                    stage '\u2778 Unit/Integration Tests'
                    unitTests()
                    stage '\u2779 Static Analysis'
                    staticAnalysis()
                    stage '\u277A Acceptance Tests'
                    getPomInfo()
                    versionNumber = extractCurrentVersion(false)
                    acceptanceTests(versionNumber)
                    if (!isBuildingPullRequest){
                        stage '\u277B Verify Chef Cookbook'
                        verifyCookbook()
                    }
                    if (!isLocal && !isBuildingPullRequest){
                        stage '\u277C Release'
                        versionNumber = getCurrentVersion(true)
                        proceed = ask('Release version ' + versionNumber + ' to nexus repository?', 1, "HOURS")
                    }
                }
                if (proceed) {
                    node("jenkins-slave") {
                        release()
                        stage '\u277D Deploy on Test'
                        def proceed_deploy = ask('Do you want to deploy version ' + versionNumber + ' to Test?', 1, "MINUTES")
                        if (proceed_deploy){
                            deploy()
                        }
                    }

                }//end proceed

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
