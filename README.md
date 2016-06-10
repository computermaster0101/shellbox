# shellbox - a library of ksh and bash compatible shell scripts

## best practices
    http://stackoverflow.com/questions/78497/design-patterns-or-best-practices-for-shell-scripts
    https://www.usenix.org/legacy/publications/library/proceedings/vhll/full_papers/korn.ksh.a
    http://mywiki.wooledge.org/Bashism
    http://rgeissert.blogspot.com/2013/11/a-bashism-week-heredocs.html
    https://www.mirbsd.org/htman/i386/man1/mksh.htm
## style guides
    http://wiki.bash-hackers.org/scripting/style
    https://google-styleguide.googlecode.com/svn/trunk/shell.xml

## Example usage:

  git archive --remote=git@bitbucket.org:mindsignited/shellbox.git master replicate -o replicate.tar && tar -xf replicate.tar &&    bash ./replicate git:git@bitbucket.org:mindsignited/shellbox.git ; \
     bash ./shellbox/java8.sh && \
     bash ./shellbox/supervisord.sh && \
     bash ./shellbox/installElasticsearch.sh ;
