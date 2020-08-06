#! /usr/bin/env zsh

# sitedocs2txt — scrape ansible site docs into many parsable text files
# Crappiest code ever.

dump() { elinks -no-numbering -no-references -dump-width 200 -dump $1 }

mkdir ../tmp/

allmods=../tmp/all-modules.lst

if [[ -f $allmods ]]; then
  print 'Already have list of modules'
else
  print 'Dumping list of all modules'
  # Really sill way to do this, but pretty safe to assume that nothing will
  # be outside of a10 and zypper.
  dump https://docs.ansible.com/list_of_all_modules.html |
    sed -nr '/• a10_server/,/• zypper_repository/ p' |
    sed -r 's/.*• //; s/\s.*//' >$allmods
fi

vimhelp() {
    modtxt=../doc/mod.txt/$1.txt
    modtmphtml=../tmp/$1.html
    modtmp=../tmp/$1.txt.tmp
    url=https://docs.ansible.com/ansible/latest/modules/${1}_module.html
    print "Dumping and creating docs for $1"
    if [[ ! -f $modtmphtml ]]; then
      print "Downloading html (and sleeping) for $1"
      wget $url -O $modtmphtml
      sleep 5
    fi
    dump $modtmphtml >|$modtmp
    ## Synopsis
    #print "SYNOPSIS                           *$1*\n" >|$modtxt
    #sed -nr '/^Synopsis¶/,/^Options¶/ p' $modtmp |
    #  sed -n '3,$p' |sed '$d' |
    #  sed -r 's/^\s+//' >>$modtxt
    ## Examples
    #print "EXAMPLES                           *$mod-examples*\n>" >>$modtxt
    #sed -nr '/^Examples¶/,/^This is a.* Module¶/ p' $modtmp |
    #  sed -n '3,$p' |sed '$d' |
    #  sed -r 's/^/   /' >>$modtxt
    titles=$(cat ../tmp/$1.txt.tmp | grep ¶ | sed -r 's/^  //g' | sed -r 's/^          .*//' | sed -r '/^$/d' | sed 's/¶//g')
    titles=("${(f)titles}")

    rm -f $modtxt
    touch $modtxt
    for ((i = 1 ; i <= ${#titles[@]} ; i++)); do
      if (( $i == 1 )); then
        print "${titles[$i]:u}                   *$1*\n" >>$modtxt
        sed -nr "/^${titles[$i]}/,/^\ {0,2}${titles[$((i+1))]}/ p" $modtmp |
          sed -n '3,$p' | sed '$d' | sed 's/\*/"/g' >>$modtxt
      elif (($i > 1 && $i < ${#titles[@]} )); then
        print "${titles[$i]:u}                   *$1-${titles[$i]:l}*\n" >>$modtxt
        sed -nr "/^${titles[$i]}/,/^\ {0,2}${titles[$((i+1))]}/ p" $modtmp |
          sed -n '3,$p' | sed '$d' | sed 's/\*/"/g' >>$modtxt
      else
        sed -nr "/^\ {0,2}${titles[$i]}/,/^\ *=*}/ p" $modtmp |
          sed -n '3,$p' | sed '$d' | sed 's/\*/"/g' >>$modtxt
      fi
    done


    print "MORE INFO                          *$1-moreinfo*\n>" >>$modtxt
    print "All arguments are omni-completed, but if you really want to see the online docs:" >>$modtxt
    print $url >>$modtxt
    #rm $modtmp $modtmphtml
}

# state completions
statecompl() {
  statesvim=../autoload/states.vim
  print 'let states = {' >|$statesvim
  while read mod; do
    modtmphtml=../tmp/$mod.html
    # blech
    states=$(awk '/<td>state<\/td>/ {x=NR+3} NR==x {gsub(/<\/?(td|ul|li)>/, " "); sub(/^\s+/, "\""); sub(/\s+$/, "\""); gsub(/\s+/, "\",\""); print}' $modtmphtml)
    grep -qP '\w' <<<$states &&
      print " \\\ '$mod': [ $states ]," >>$statesvim
  done <$allmods
  print " \\\ }" >>$statesvim
}

mkdir -p ../doc/mod.txt
while read mod; do
  vimhelp $mod &
  sleep 0.2
done <$allmods

wait $(jobs -p)

statecompl

print 'Generating all vim docs'
vim -c ':helptags ../doc |q'

print 'You may want to clean up ../tmp now.'
