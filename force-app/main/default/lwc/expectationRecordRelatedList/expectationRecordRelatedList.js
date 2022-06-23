//BROKEN JS with getobjfields commented
/**
 * @description       :
 * @author            : Edwin Revolorio
 * @group             :
 * @last modified on  : 03-11-2022
 * @last modified by  : Edwin Revolorio
 * Modifications Log
 * Ver   Date         Author         Modification
 * 1.0   03-11-2022   Edwin Revolorio   Initial Version
**/
import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getExpectationRecords from '@salesforce/apex/ExpectationRecordRelatedListController.getExpectationRecords';
import { refreshApex } from '@salesforce/apex';
import { getRecord } from 'lightning/uiRecordApi';
import getObjFieldsForLWC from '@salesforce/apex/ExpectationRecordRelatedListController.getObjFieldsForLWC';

export default class ExpectationRecordRelatedListLWC extends LightningElement {
    @api recordId;
    @track objFields;
    @track parentRecord;
    @track expRecordList;
    @track isLoading = false;
    lastUpdateTime = new Date();

    @track fieldColumns = [
        {label: 'Seq', fieldName: 'Sequence__c', type:'number', hideDefaultActions: "true", initialWidth: 50,
        /*typeAttributes: {label: {fieldName: 'Name'}, target: '_blank'}*/
        },
        {label: 'Expected Action', fieldName: 'Name', type:'text',
            /*typeAttributes: {label: {fieldName: 'Name'}, target: '_blank'}*/
        },
        {label: 'Start', fieldName: 'StartTime__c', type: 'date',
            typeAttributes: {
                month: '2-digit',
                day: '2-digit',
                year: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }},
        {label: 'Due', fieldName: 'DueBy__c', type: 'date',
            typeAttributes: {
                month: '2-digit',
                day: '2-digit',
                year: '2-digit',
                hour: '2-digit',
                minute: '2-digit'
            }},
        {label: 'Status', type: 'customDate', cellAttributes: { alignment: 'left' },
            typeAttributes: {
                completion: { fieldName: 'completion'},
                isCompleted: { fieldName: 'isCompleted'},
                varDate: { fieldName: 'DueBy__c'},
                noCompletionDate: { fieldName: 'noCompletionDate'},
                status: {fieldName: 'Status__c'}
            }
        }
    ];

    //Retrieves the context record's fields
    @wire(getObjFieldsForLWC, { recordId: '$recordId'})
    wiredObjFields({ data, error }) {
        console.log('objFields => ', data, error);
        if (data) {
            console.log('objFields = ' + data);
            this.objFields = data;
        } else if (error) {
            console.error('objFields ERROR => ', JSON.stringify(error)); // handle error properly
        }
    }

    //Retrieves the context record
    //This wire will also update the related list when the record is updated
    @wire(getRecord, { recordId: '$recordId', fields: '$objFields'})
    getParentRecord({ data, error }) {
        console.log('parentRecord => ', data, error);
        if (data) {
            console.log('getPR: ' + data);
            this.parentRecord = data;
            console.log('parentRecord = ' + this.parentRecord);
            this.getEvalER();
        } else if (error) {
            console.error('ERROR => ', JSON.stringify(error)); // handle error properly
        }
    }
    
    //Gets the initial data for the table
    connectedCallback(){
        console.log('entering connected Callback');
        console.log('recordId = ' + this.recordId);
        this.getEvalER();
    }

    //Helper method for getting and evaluating the expectation records using the controller
    getEvalER(){
        getExpectationRecords({recordId: this.recordId})
        .then(result => {
            var tempExpList = [];

            // loop through each reacord
            for (var i=0; i<result.length; i++){
                let tempRecord = Object.assign({}, result[i]);
                //tempRecord.expecationUrl = "/" + tempRecord.Id;

                // if the status is Completed, change icon to green check and sets the text 'Completed'
                if(tempRecord.Status__c === 'Completed'){
                    tempRecord.completion = 'standard:task2';
                    tempRecord.isCompleted = true;
                } else if (tempRecord.Status__c === 'Upcoming'){ // if Upcoming, change icon to orange Zz and sets relative datetime
                    tempRecord.completion = 'standard:waits';
                    tempRecord.DueBy__c = new Date(tempRecord.DueBy__c);
                    tempRecord.isCompleted = false;
                } else if (tempRecord.Status__c === 'Overdue'){ // if Overdue, change icon to red X and sets relative datetime
                    tempRecord.completion = 'standard:first_non_empty';
                    tempRecord.DueBy__c = new Date(tempRecord.DueBy__c);
                    tempRecord.isCompleted = false;
                } else if(tempRecord.Status__c === 'Bypassed'){
                    tempRecord.completion = 'standard:duration_downscale';
                    tempRecord.DueBy__c = new Date(tempRecord.DueBy__c);
                    tempRecord.isCompleted = false;
                }

                console.log(tempRecord.CompletionTime__c);

                //add the records to the list
                tempExpList.push(tempRecord);
            }

            // data is loaded, turn off spinner
            this.isLoading = false;
            this.expRecordList = tempExpList;
            console.log(result);
            this.updateLastModifiedTime();
        })
        .catch(error => {
            this.isLoading = false;
            console.log(error);
        });
        
    } 

    //Handles the refresh button press
    handleRefresh(){
        this.updateLastModifiedTime();
    }

    updateLastModifiedTime(){
        this.lastUpdateTime = Date.now();
    }
}