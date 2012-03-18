(* AppleScript wrapper for Jenkins CI server.

Because Jenkins is an application with no GUI
(other than the Web UI), this little app can be used
to easily start and stop it.

Copyright (c) 2011, 2012 Sami Tikka

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE. *)

property commandlineArgs : ""

on run
	set path_to_wait to (path to resource "wait_for_jenkins.sh" in bundle (path to me))
	try
		set path_to_war to path to resource "jenkins.war" in bundle (path to me)
		info for (path_to_war as alias) size yes
		set size_of_war to the size of the result
		if size_of_war is less than 30000000 then
			error "jenkins.war is too small" number 1001
		end if
		set war_exists to true
	on error
		set path_to_war to (path to me as string) & "Contents:Resources:jenkins.war"
		set war_exists to false
	end try
	
	if not war_exists then
		try
			display alert "Click OK to start downloading jenkins.war. Another dialog will appear when download has finished."
			do shell script "curl -sfL http://mirrors.jenkins-ci.org/war/latest/jenkins.war -o " & (quoted form of POSIX path of (path_to_war as text))
		on error
			display alert "Something went wrong in downloading jenkins.war. Download it manually into " & (POSIX path of path_to_war as text)
			quit
		end try
	end if
	
	set jenkins_is_running to true
	try
		do shell script "launchctl list org.jenkins-ci.jenkins >/dev/null"
	on error
		set jenkins_is_running to false
	end try
	
	if jenkins_is_running then
		display dialog "Found an already-running Jenkins and adopted that." with title "Jenkins" with icon (path to resource "Jenkins.icns" in bundle (path to me)) buttons {"OK"}
	else
		try
			display dialog "Run Jenkins with these arguments:" & return & "(e.g. --httpPort=N --prefix=/jenkins ... It is OK to leave it empty too.)" default answer commandlineArgs with title "Jenkins" with icon (path to resource "Jenkins.icns" in bundle (path to me))
			set commandlineArgs to (text returned of the result)
			do shell script "launchctl submit -l org.jenkins-ci.jenkins -- java -jar " & (quoted form of POSIX path of (path_to_war as text)) & " " & commandlineArgs
			try
				do shell script (quoted form of POSIX path of (path_to_wait as text)) & " http://localhost:8080/"
				open location "http://localhost:8080/"
			on error
				display alert "Unable to find Jenkins in port 8080" message "If you changed the default port, you must open the browser to Jenkins yourself." as informational
			end try
		on error errMsg number errNum
			if errNum is equal to -128 then
				quit
			else
				display alert "Failed to launch Jenkins. Sorry." message errMsg as critical
				quit
			end if
		end try
	end if
end run

on quit
	try
		do shell script "launchctl remove org.jenkins-ci.jenkins"
	end try
	continue quit
end quit