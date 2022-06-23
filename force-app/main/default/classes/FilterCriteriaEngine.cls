public class FilterCriteriaEngine {
    
    public static Boolean parseCriteria(SObject objRec, string strCriteria){
        if(string.isBlank(strCriteria)){
            return true;
        }
        Boolean isTrue = false;
        if(strCriteria.contains('(') || strCriteria.contains(')')){            
            isTrue = parseFilterCriteriaWithParentheses(objRec, strCriteria);
        } else {
            isTrue = parseFilterCriteria(objRec, strCriteria);
            //Do we need this?
            //TODO yes, otherwise this will return null for expressions that dont have parens. 12/14 zh
        }        
        return isTrue;        
    }
    
   //This recursive method can be used to parse nested expressions
    public static boolean parseFilterCriteria(sObject record, String expression){
        System.debug('Entering Parse  ' + expression);
        List<String> subExpressions = new List<String>();
        boolean finalValue = NULL;
        List<boolean> resultsList = new List<boolean>();
        List<string> logicOperatorList = new List<string>();

        //given: 'field >= field value' for each expression
        string logicRegex = '([^\\s]+) ([<->!]{1,2}) (.+) ([^\\s]{1,3})';
        string nonLogicalRegex = '([^\\s]+) ([<->!]{1,2}) (.+)';
        string operatorRegex = '([<->!]{1,2})';
        Pattern logicPattern = Pattern.compile(logicRegex);
        Pattern nologicPattern = Pattern.compile(nonLogicalRegex);
        Pattern operatorPattern = Pattern.compile(operatorRegex);

        //If expression contains multiple lines: break by line. Otherwise, break at Logical operators
        if(expression.contains('\n')){
            subExpressions = expression.split('[\n]+');
        }
        else if(expression.contains('OR') || expression.contains('AND')){
            subExpressions = expression.split('(?<=AND|OR)+');
        }
        else{
            subExpressions.add(expression);
        }

        for(string subExp : subExpressions){
            System.Debug('subexpressions: ' + subExp );
        }

        //compile list of results
        for(string currExpression : subExpressions){
            matcher operatorMatcher = operatorPattern.matcher(currExpression.trim());
            integer operatorCount = 0;
            while(operatorMatcher.find()){
                operatorCount++;
            }
            //recursively parse subexpressions if they contain more than one conditional operator
            if(operatorCount > 1 ){
                System.debug('Found more than one conditional operator!');
                resultsList.add(parseFilterCriteria(record,currExpression));
            }
            else if(operatorCount == 0){
                if(currExpression.contains('true')){
                    resultsList.add(Boolean.ValueOf('true'));
                }
                else if(currExpression.contains('false')){
                    resultsList.add(Boolean.ValueOf('false'));
                }
                else{
                    System.debug('No operator found!');
                }
            }

            //evaluate the subexpression and add its result to the resultsList for bitwise computation later on
            else{
                matcher logicalMatcher = logicPattern.matcher(currExpression.trim());
                System.debug('logicalMatcher found a match? ' + logicalMatcher.matches());
                matcher nologicMatcher = nologicPattern.matcher(currExpression.trim());
                boolean currExpResult = FALSE;

                if(logicalMatcher.matches() && logicalMatcher.hitEnd() && logicalMatcher.groupCount() == 4){
                    system.debug('Line matches! (Field: '+ logicalMatcher.group(1).trim() + ') (Conditional Operator: '+logicalMatcher.group(2).trim() + ') (Value: ' + logicalMatcher.group(3).trim() + ') (Logical Operator: ' + logicalMatcher.group(4).trim() + ')');
                    currExpResult = evaluateFilterExpression(record, logicalMatcher);
                    system.debug('Expression equals: ' + currExpResult);
                }
                else if(nologicMatcher.matches() && nologicMatcher.hitEnd() && nologicMatcher.groupCount() == 3){
                    system.debug('Final line matches! (Field: '+ nologicMatcher.group(1).trim() + ') (Conditional Operator: '+nologicMatcher.group(2).trim() + ') (Value: ' + nologicMatcher.group(3).trim()+')') ;
                    currExpResult = evaluateFilterExpression(record, nologicMatcher);
                    system.debug('Expression equals: ' + currExpResult);
                }
                else if(currExpression.trim() == 'true' || currExpression.trim() =='false'){
                    // TODO: 
                }
                else{
                    system.debug('No match: line :'+ currExpression);
                }
                //compile list of results
                resultsList.add(currExpResult);
            }
                //compile list of logical operators from the ends of the subexpressions
                if(currExpression.trim().Right(3).contains('AND')){
                    logicOperatorList.add('AND');
                }
                else if(currExpression.trim().Right(2).contains('OR')){
                    logicOperatorList.add('OR');
                }
        }

        //Evaluate cumulative expression using bitwise logical operators.
        System.debug('Results list: ' + resultsList);
        System.debug('Logical operator list: ' + logicOperatorList);
        boolean isFirst = true;
        for(integer i = 0; i < resultsList.size(); i++){
            if(i == 0){
                finalValue = resultsList[i];
            }
            else{
                if(logicOperatorList[i-1].equals('AND')){
                    finalValue &= resultsList[i];
                }
                else if(logicOperatorList[i-1].equals('OR')){
                    finalValue |= resultsList[i];
                }
                System.debug('finalValue is: ' + finalValue);
            }
        }
        return finalValue;
    }

    private static boolean evaluateFilterExpression(sObject currRecord, matcher currMatcher){
        boolean expressionResult = true;
        System.debug('Entering evaluateFIlterExpression');
        system.debug('Matcher group 0: ' + currMatcher.group(0));
        system.debug('Matcher group 1: ' + currMatcher.group(1));
        //Get field type
        string fieldType = String.valueOf(currRecord.getSObjectType().getDescribe().fields.getMap().get(String.valueOf(currMatcher.group(1).trim())).getDescribe().getType());

        switch on fieldType{
            when 'PICKLIST', 'STRING', 'PHONE', 'REFERENCE'{
                expressionResult = evalStringExpr(String.valueOf(currRecord.get(currMatcher.group(1).trim())), currMatcher.group(2).trim(), currMatcher.group(3).trim());
            }
            when 'INTEGER', 'DOUBLE'{
                expressionResult = evalNumExpr(Integer.ValueOf(currRecord.get(currMatcher.group(1).trim())), currMatcher.group(2).trim(), Integer.ValueOf(currMatcher.group(3).trim()));
            }             
            when 'DATETIME'{
                if (currMatcher.group(3).trim().contains(':')) { //assume it's a datetime
                    DateTime inputValue = Datetime.valueOf(currMatcher.group(3).trim());
                    expressionResult = evalDateExpr(DateTime.ValueOf(currRecord.get(currMatcher.group(1).trim())), currMatcher.group(2).trim(), inputValue, true);
                } else {
                    Date inputValue = Date.parse(currMatcher.group(3).trim());
                    expressionResult = evalDateExpr(Date.ValueOf(currRecord.get(currMatcher.group(1).trim())), currMatcher.group(2).trim(), inputValue, false);
                }
            } 
            when else{
                Throw new InvalidCriteriaException('Field Data Type Error.');
            }
        }
        return expressionResult;
    }

    private static boolean evalStringExpr(String fieldValue, String operator, String inputValue){
        boolean exprResult = FALSE;
        switch on operator{
            when '==', '=' {
                exprResult = fieldValue.Equals(inputValue);
            }
            when '>'{
                exprResult = fieldValue > inputValue;
            }
            when '>='{
                exprResult = fieldValue >= inputValue;

            }
            when '<'{
                exprResult = fieldValue < inputValue;
            }
            when '<='{
                exprResult = fieldValue <= inputValue;
            }
            when '<>', '!='{
                exprResult = !fieldValue.Equals(inputValue);
            }
            when else{
                Throw new InvalidCriteriaException('Operator Type Error.');
            }
        }        
        return exprResult;
    }

    private static boolean evalNumExpr(Integer fieldValue, String operator, Integer inputValue){
        System.debug('evaluating Number Expression!');
        boolean exprResult = FALSE;
        switch on operator{
            when '==', '=' {
                exprResult = fieldValue == inputValue;
            }
            when '>'{
                exprResult = fieldValue > inputValue;
            }
            when '>='{
                exprResult = fieldValue >= inputValue;
            }
            when '<'{
                exprResult = fieldValue < inputValue;
            }
            when '<='{
                exprResult = fieldValue <= inputValue;
            }
            when '<>', '!='{
                exprResult = fieldValue != inputValue;
            }
            when else{
                Throw new InvalidCriteriaException('Operator Type Error.');
            }
        }        
        return exprResult;
    }

    private static boolean evalDateExpr(DateTime fieldValue, String operator, DateTime inputValue, Boolean compareTime){
        System.debug('evaluating Date Expression!');
        boolean exprResult = FALSE;

        if(!compareTime) { //strip times if necessary
            fieldValue = Date.newInstance(fieldValue.year(), fieldValue.month(), fieldValue.day());
            inputValue = Date.newInstance(inputValue.year(), inputValue.month(), inputValue.day());
        }
        switch on operator{
            when '==', '=' {
                exprResult = fieldValue == inputValue;
            }
            when '>'{
                exprResult = fieldValue > inputValue;
            }
            when '>='{
                exprResult = fieldValue >= inputValue;
            }
            when '<'{
                exprResult = fieldValue < inputValue;
            }
            when '<='{
                exprResult = fieldValue <= inputValue;
            }
            when '<>', '!='{
                exprResult = fieldValue != inputValue;
            }
            when else{
                System.debug('Operator Type Error.');
            }
        }
        
        return exprResult;
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    /////////////////// Below are the Methods for parsing with parentheses ////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////

       //This recursive method can be used to parse nested expressions
    public static boolean parseFilterCriteriaWithParentheses(sObject record, String expression){
        System.debug('Entering parseFilterCriteriaWithParentheses ' + expression);
        //START variables for parsing with parentheses
        String ANDv = 'AND';
        String ORv = 'OR';
        String OPEN = '(';
        String CLOSE = ')';
        String finalExpression;
        Boolean finalValue;
        //END variables for parsing with parentheses

        List<String> subExpressions = expression.split('[\n]+');
        String oneLineExpr = ' ';
        for(String currExpr : subExpressions){
            if(currExpr.trim().Right(3).contains('AND')){
                oneLineExpr += '(' + currExpr.substring(0,currExpr.length()-4) + ') AND';
            }
            else if(currExpr.trim().Right(2).contains('OR')){
                oneLineExpr += '(' + currExpr.substring(0,currExpr.length()-3) + ') OR';
            }
            else{
                oneLineExpr += '(' + currExpr + ')';
            }
        }

        // for(string currExpression : subExpressions){
        //     //compile list of results
        //     finalExpression = String.isEmpty(finalExpression) ? String.valueOf(evaluateExpressionParentheses(record, oneLineExpr.Trim())) : finalExpression + String.valueOf(evaluateExpressionParentheses(record, currExpression.Trim()));
        //     system.debug('parse finalExpression = ' + finalExpression);

        //     //compile list of logical operators from the ends of the subexpressions
        //     if(currExpression.trim().Right(3).contains('AND')){
        //         finalExpression += ' AND ';
        //     }
        //     else if(currExpression.trim().Right(2).contains('OR')){
        //         finalExpression += ' OR ';
        //     }

        // }
        
        finalValue = evaluateExpressionParentheses(record, oneLineExpr.Trim());
        System.debug('FINAL value = ' + finalValue);
        return finalValue;
    }

    private static Boolean evaluateExpressionParentheses(sObject record, String expression){
        System.debug('Entering evaluateExpressionParentheses with expression: '+ expression);
        //START variables for parsing with parentheses
        String ANDv = 'AND';
        String ORv = 'OR';
        String OPEN = '(';
        String CLOSE = ')';
        Boolean[] values;
        String finalExpression;
        //END variables for parsing with parentheses
        Boolean finalValue;

        While(expression.contains(OPEN)){
            //Get most nested parentheses
                    Integer indexOfOpen = -1;
                    Integer indexOfClose = -1;            
                    String[] chars = expression.split('');
                    for(Integer i = 0; i < chars.size(); i++){            
                        String singleChar = chars[i];            
                        if(singleChar == OPEN) {
                            indexOfOpen = i;
                            continue;
                        }            
                        if(singleChar == CLOSE) {
                            indexOfClose = i;
                            break;
                        }
                    }
                    String subExpression = expression.substring(indexOfOpen + 1 , indexOfClose);

                    //Evaluate Tokens and replace expression with result
                    if(subExpression.Trim() != 'true' && subExpression.Trim() !='false'){
                        expression = expression.replace( OPEN + subExpression + CLOSE, String.valueOf(parseFilterCriteria(record, subExpression.Trim())));
                    }
                    else{
                        expression = expression.replace( OPEN + subExpression + CLOSE, subExpression.Trim());
                    }
                    System.debug(subExpression);
                    System.debug(expression);
                    System.debug('########');
        }
            List<String> subExpressionsWithLogic = new list<String>();
            List<String> subExpressionsNoLogic = new list<String>();
            if(expression.contains('OR') || expression.contains('AND')){
                subExpressionsWithLogic = expression.split('(?<=AND|OR)+');
                subExpressionsNoLogic = expression.split('(?:AND|OR)+');
            }
            System.Debug('subExpressionsNoLogic = ' + subExpressionsNoLogic);
            for(Integer i = 0; i < subExpressionsWithLogic.Size(); i++){
                if(subExpressionsNoLogic[i].Trim() != 'true' && subExpressionsNoLogic[i].Trim() != 'false'){
                    expression = expression.replace(subExpressionsNoLogic[i], String.valueOf(parseFilterCriteria(record, subExpressionsWithLogic[i].Trim())));
                }
            }
        system.debug('eval expression = ' + expression);
        finalValue = evalBooleanExpression(expression);
        return finalValue;
    }

    private static boolean evalBooleanExpression(String expression){
        System.Debug('Entering evalBooleanExpression with expression: ' + expression);
        Boolean Result = false;
        String ANDv = 'AND';
        String ORv = 'OR';

        for( String conj : expression.split(ORv) ){
            Boolean b = true;
            for( String single : conj.split(ANDv) ){
                b &= Boolean.valueOf(single.trim());
            }
            Result |= b;
        }

        System.Debug('Exiting evalBooleanExpression with result: ' + Result);
        return Result;
    }
    
    public class InvalidCriteriaException extends Exception {}
    
}