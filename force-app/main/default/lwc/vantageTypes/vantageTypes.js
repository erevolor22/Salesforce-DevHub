// custom date type for Expectation Related Table LWC
import LightningDatatable from 'lightning/datatable';
import customDate from './customDate.html';

export default class MyTypes extends LightningDatatable {
    static customTypes = {
        customDate: {
            template: customDate,
            standardCellLayout: false,
            typeAttributes: ['varDate','completion', 'isCompleted', 'noCompletionDate', 'status'],
        }
    }
}