#!/bin/bash

source ./git-remerge/functions.sh

REMOVE_PARENT_FILES=true  # Default is `true`. You may change this to `false`.
REMOVE_CONFLICT_FILE=true  # Default is `true`. You may change this to `false`.
REMOVE_ORIG_FILE=true  # Default is `true`. You may change this to `false`.


# Assert the given amount of `ARGS` is legal.
ARGS=("$@")
NUMBER_OF_ARGS=${#ARGS[@]}
MINIMUM_NUMBER_OF_ARGS=1
if [ $NUMBER_OF_ARGS -ne $MINIMUM_NUMBER_OF_ARGS ]; then
    echo "Wrong number of arguments. Should be exactly $MINIMUM_NUMBER_OF_ARGS, but was $NUMBER_OF_ARGS.";
    exit 1;    
fi

# ---------------------------------- Code -------------------------------------

LOG_TITLE="### git-remerge.sh ###: "

THEIRS_COMMIT="${ARGS[0]}"

BASE_COMMIT=$(git merge-base --octopus HEAD $THEIRS_COMMIT)  # Get base commit before the "merge" execution.
git merge $THEIRS_COMMIT --no-ff  # Execute merge.
git checkout $THEIRS_COMMIT . --merge > /dev/null 2>&1  # Force checkout all their files to see the conflicted files.
REMERGE_DIFF_FILE=git-remerge-diff.txt
git diff HEAD --name-only > $REMERGE_DIFF_FILE
FILE_PATH_LIST=$(readFile $REMERGE_DIFF_FILE)
git reset --hard

NEW_FILE_PATH_LIST=()
for FILE_PATH in $FILE_PATH_LIST; do

    : '
    More info about string extraction:
    - [here](https://stackoverflow.com/a/965069/14427765).
    - [here](https://stackoverflow.com/a/44350542/14427765).
    '
    FILE_PATH_WITHOUT_EXTENSION=$(echo "${FILE_PATH%.*}")
    FILE_LAST_DIR_PATH=$(echo "${FILE_PATH%/*}")
    FILE_NAME_WITHOUT_EXTENSION=$(echo "${FILE_PATH_WITHOUT_EXTENSION#$FILE_LAST_DIR_PATH/}")
    FILE_NAME=$(echo "${FILE_PATH#$FILE_LAST_DIR_PATH/}")
    FILE_EXTENSION=$(echo "${FILE_PATH#*.}")

    # Define parent names and paths.
    BASE_PARENT_NAME=$FILE_NAME_WITHOUT_EXTENSION.base.$FILE_EXTENSION
    OURS_PARENT_NAME=$FILE_NAME_WITHOUT_EXTENSION.ours.$FILE_EXTENSION
    THEIRS_PARENT_NAME=$FILE_NAME_WITHOUT_EXTENSION.theirs.$FILE_EXTENSION
    BASE_PARENT_PATH=$FILE_LAST_DIR_PATH/$BASE_PARENT_NAME
    OURS_PARENT_PATH=$FILE_LAST_DIR_PATH/$OURS_PARENT_NAME
    THEIRS_PARENT_PATH=$FILE_LAST_DIR_PATH/$THEIRS_PARENT_NAME

    # ------ Start skip the following files ------

    if [[ "$FILE_NAME" == "git-remerge.sh" ]]; then
        continue
    fi

    # ------ End skip the following files ------

    NEW_FILE_PATH_LIST+=("$FILE_PATH")  # Add the current `FILE_PATH`

    # Print logs.
    echo $LOG_TITLE "Diff In: $FILE_PATH"

    # Create parent files.
    git show $BASE_COMMIT:$FILE_PATH > $BASE_PARENT_PATH
    git show HEAD:$FILE_PATH > $OURS_PARENT_PATH
    git show $THEIRS_COMMIT:$FILE_PATH > $THEIRS_PARENT_PATH

    # Merge file.
    # git merge-file -p $OURS_PARENT_PATH $BASE_PARENT_PATH $THEIRS_PARENT_PATH > $FILE_PATH
    
    : '
    Make sure to add a newline at the end of the file, if there isn`t already.
    To avoid the `\ No newline at end of file` error message in the result `$CONFLICT_FILE`.
    '
    sed -i -e '$a\' $OURS_PARENT_PATH
    sed -i -e '$a\' $THEIRS_PARENT_PATH

    # Create a manual conflict file.
    CONFLICT_FILE=$FILE_PATH.conflict
    git diff --no-index -U$(wc -l $OURS_PARENT_PATH | awk '{print $1}') $OURS_PARENT_PATH $THEIRS_PARENT_PATH --output $CONFLICT_FILE

    # Remove all lines until the line that begin with `+++` (included).
    sed -i '1,/^+++/d' $CONFLICT_FILE

    # Remove all lines that begin with `@@` and contain the characters `-` `,` `+` `,` (by this order) and end with `@@`.
    sed -i '/^@@.*-.*,.*\+.*,.*@@$/d' $CONFLICT_FILE

    # Convert file to string list.
    readarray -t CONFLICT_FILE_AS_STRING_LIST < $CONFLICT_FILE

    : '
    Conflict parse algorithm:

    parse the file 3 times:

    1:
    - delete until the first empty line (included)
    - if you see a line that begins with `@@` and contains `-` `,` `+` then delete it.

    2:
    - if you see a line that begins with `-`, then add a `<<<<<<< HEAD` on the line above it,
    and include all the next lines that begin with `-` under it, until you do not see a line that begins with a `-`.
    - then, add a new line of : `=======`.
    - Then, include all the lines that begin with `+`, until you do not see a line that begins with a `+`.
    and add new line of `>>>>>>> $THEIRS_COMMIT`

    3:
    - if you see a line that begins with `+`, then add a `=======` on the line above it, and a new line of `<<<<<<< HEAD` on the line above the `=======` line.
    - include all the next lines that begin with `+` under the first line you have found, until you do not see a line that begins with a `+`.
    - then, add a new line of : `>>>>>>> $THEIRS_COMMIT`.

    See Guides:
    sed:
    - https://stackoverflow.com/a/17365113/14427765
    - https://www.theunixschool.com/2014/08/sed-examples-remove-delete-chars-from-line-file.html
    - https://fabianlee.org/2018/10/28/linux-using-sed-to-insert-lines-before-or-after-a-match/
    - https://www.gnu.org/software/sed/manual/sed.html
    - https://fabianlee.org/2019/10/05/bash-setting-and-replacing-values-in-a-properties-file-use-sed/
    - https://stackoverflow.com/a/9453461/14427765

    arrays:
    - https://unix.stackexchange.com/questions/328882/how-to-add-remove-an-element-to-from-the-array-in-bash
    '

    # Set conflict titles.
    BASE_CONFLICT_TITLE="|||||||"
    HEAD_CONFLICT_TITLE="<<<<<<< HEAD"
    CENTER_CONFLICT_TITLE="======="
    THEIRS_CONFLICT_TITLE=">>>>>>> $THEIRS_COMMIT"

    # Set chars.
    BASE_CHAR="|"
    HEAD_CHAR="-"
    CENTER_CHAR=""
    THEIRS_CHAR="+"

    # Iterate Over The `CONFLICT_FILE_AS_STRING_LIST` To Parse Diff To Conflict Titles.

    # --------------------------- Algorithm Start -----------------------------

    CURRENT_CHAR="$CENTER_CHAR"
    PREV_CHAR="$CURRENT_CHAR"

    for ((i = 0; i < ${#CONFLICT_FILE_AS_STRING_LIST[@]}; i++)); do
        LINE="${CONFLICT_FILE_AS_STRING_LIST[i]}"
        CURRENT_CHAR="${LINE::1}"

        # Delete the first character from the line (`CURRENT_CHAR`).
        CONFLICT_FILE_AS_STRING_LIST[i]="${LINE:1}"
        
        # In case `$HEAD_CHAR` series has started.
        if [ "$CURRENT_CHAR" == "$HEAD_CHAR" ] && [ "$CURRENT_CHAR" != "$PREV_CHAR" ]; then

            # Insert a new `$HEAD_CONFLICT_TITLE` line before the current line.
            CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$HEAD_CONFLICT_TITLE" "${CONFLICT_FILE_AS_STRING_LIST[@]:i}")
            ((i++))
        fi

        # In case `$HEAD_CHAR` series has ended.
        if [ "$PREV_CHAR" == "$HEAD_CHAR" ] && [ "$CURRENT_CHAR" != "$PREV_CHAR" ]; then

            # Insert a new `$CENTER_CONFLICT_TITLE` line before the current line.
            CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$CENTER_CONFLICT_TITLE" "${CONFLICT_FILE_AS_STRING_LIST[@]:i}")
            ((i++))
        fi

        # In case there is no upcoming `$THEIRS_CHAR`.
        if [ "${CONFLICT_FILE_AS_STRING_LIST[i - 1]}" == "$CENTER_CONFLICT_TITLE" ] && [ "$CURRENT_CHAR" != "$THEIRS_CHAR" ]; then

            # Insert a new `$THEIRS_CONFLICT_TITLE` line before the current line.
            CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$THEIRS_CONFLICT_TITLE" "${CONFLICT_FILE_AS_STRING_LIST[@]:i}")
            ((i++))
        fi

        # In case `$THEIRS_CHAR` series has started.
        if [ "$CURRENT_CHAR" == "$THEIRS_CHAR" ] && [ "$CURRENT_CHAR" != "$PREV_CHAR" ]; then

            # In case there is not already a `$CENTER_CONFLICT_TITLE` in the previous line.
            if [[ "${CONFLICT_FILE_AS_STRING_LIST[i - 1]}" != "$CENTER_CONFLICT_TITLE" ]]; then

                # Insert a new `$HEAD_CONFLICT_TITLE` and `$CENTER_CONFLICT_TITLE` lines before the current line.
                CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$HEAD_CONFLICT_TITLE" "$CENTER_CONFLICT_TITLE" "${CONFLICT_FILE_AS_STRING_LIST[@]:i}")
                ((i++))
                ((i++))
            fi
        fi

        # In case `$THEIRS_CHAR` series has ended.
        if [ "$PREV_CHAR" == "$THEIRS_CHAR" ] && [ "$CURRENT_CHAR" != "$PREV_CHAR" ]; then

            # Insert a new `$THEIRS_CONFLICT_TITLE` line before the current line.
            CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$THEIRS_CONFLICT_TITLE" "${CONFLICT_FILE_AS_STRING_LIST[@]:i}")
            ((i++))
        fi

        PREV_CHAR="$CURRENT_CHAR"
    done

    # In case the last line is a `$HEAD_CHAR`.
    if [[ "$CURRENT_CHAR" == "$HEAD_CHAR" ]]; then

        # Insert a new `$CENTER_CONFLICT_TITLE` and `$THEIRS_CONFLICT_TITLE` lines after the current line.
        CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$CENTER_CONFLICT_TITLE" "$THEIRS_CONFLICT_TITLE")
    fi

    # In case the last line is a `$THEIRS_CHAR`.
    if [[ "$CURRENT_CHAR" == "$THEIRS_CHAR" ]]; then

        # Insert a new `$THEIRS_CONFLICT_TITLE` line after the current line.
        CONFLICT_FILE_AS_STRING_LIST=("${CONFLICT_FILE_AS_STRING_LIST[@]:0:i}" "$THEIRS_CONFLICT_TITLE")
    fi

    # Convert `$CONFLICT_FILE_AS_STRING_LIST` to .orig file.
    ORIG_FILE=$FILE_PATH.orig
    printf "%s\n" "${CONFLICT_FILE_AS_STRING_LIST[@]}" > $ORIG_FILE

    # ---------------------------- Algorithm End ------------------------------

    # Overwrrite "our" file with .orig file.
    cp -f $ORIG_FILE $FILE_PATH

    # Remove helper files.
    if [[ $REMOVE_PARENT_FILES ]]; then
        rm $BASE_PARENT_PATH
        rm $OURS_PARENT_PATH
        rm $THEIRS_PARENT_PATH
    fi

    if [[ $REMOVE_CONFLICT_FILE ]]; then
        rm $CONFLICT_FILE
    fi

    if [[ $REMOVE_ORIG_FILE ]]; then
        rm $ORIG_FILE
    fi
    
((j++))
done

# Update `FILE_PATH_LIST` only to the files that were iterated.
FILE_PATH_LIST=${NEW_FILE_PATH_LIST[@]}
unset NEW_FILE_PATH_LIST

# -------------------------------- Message ------------------------------------

LOG_HALF_BOUNDARY_SHORT="##########################"
LOG_HALF_BOUNDARY="#$LOG_HALF_BOUNDARY_SHORT"

echo $LOG_HALF_BOUNDARY_SHORT START GIT-REMERGE SUMMARY $LOG_HALF_BOUNDARY

HEAD_NAME=$(git symbolic-ref --short HEAD)

# Commit the changes.
# git commit -m "Remerge Conflicts From '$THEIRS_COMMIT' To '$HEAD_NAME'"

echo "The following files have conflicts that need to be resolved:"
echo 

for i in $FILE_PATH_LIST; do
    echo $i
done

echo $LOG_HALF_BOUNDARY_SHORT FINISH GIT-REMERGE SUMMARY $LOG_HALF_BOUNDARY

# Remove helper file.
rm $REMERGE_DIFF_FILE

exit