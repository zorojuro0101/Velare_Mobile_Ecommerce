// Rider ID Documents Modal functionality
// Store file objects for form submission
let riderOrcrFileObj = null;
let riderDriverLicenseFileObj = null;
let riderVehicleType = null;
let riderPlateNumber = null;

// Use event delegation to handle button clicks
document.addEventListener('click', function(e) {
    // Handle rider ID modal button click
    if (e.target && e.target.id === 'rider_id_modal_btn') {
        e.preventDefault();
        e.stopPropagation();
        console.log('Rider ID modal button clicked via delegation');
        
        const riderIdDocumentsModal = document.getElementById('riderIdDocumentsModal');
        if (riderIdDocumentsModal) {
            const rect = e.target.getBoundingClientRect();
            const modalWidth = 500;
            const fieldCenter = rect.left + (rect.width / 2);
            const modalLeft = fieldCenter - (modalWidth / 2);
            
            riderIdDocumentsModal.style.bottom = `${window.innerHeight - rect.top + window.scrollY + 6}px`;
            riderIdDocumentsModal.style.left = `${modalLeft + window.scrollX}px`;
            riderIdDocumentsModal.style.top = 'auto';
            riderIdDocumentsModal.style.display = 'block';
            
            // Check required files
            const riderOrcrUpload = document.getElementById('rider_orcr_upload');
            const riderDriverLicenseUpload = document.getElementById('rider_driver_license_upload');
            const confirmRiderIdDocumentsBtn = document.getElementById('confirmRiderIdDocumentsBtn');
            const orcrUploaded = riderOrcrUpload && riderOrcrUpload.files && riderOrcrUpload.files.length > 0;
            const driverLicenseUploaded = riderDriverLicenseUpload && riderDriverLicenseUpload.files && riderDriverLicenseUpload.files.length > 0;
            confirmRiderIdDocumentsBtn.disabled = !(orcrUploaded && driverLicenseUploaded);
        }
        return false;
    }
    
    // Handle rider plate modal button click
    if (e.target && e.target.id === 'rider_plate_modal_btn') {
        e.preventDefault();
        e.stopPropagation();
        console.log('Rider plate modal button clicked via delegation');
        
        const riderVehiclePlateModal = document.getElementById('riderVehiclePlateModal');
        if (riderVehiclePlateModal) {
            const rect = e.target.getBoundingClientRect();
            const modalWidth = 500;
            const fieldCenter = rect.left + (rect.width / 2);
            const modalLeft = fieldCenter - (modalWidth / 2);
            
            riderVehiclePlateModal.style.bottom = `${window.innerHeight - rect.top + window.scrollY + 6}px`;
            riderVehiclePlateModal.style.left = `${modalLeft + window.scrollX}px`;
            riderVehiclePlateModal.style.top = 'auto';
            riderVehiclePlateModal.style.display = 'block';
            
            // Check vehicle & plate fields
            const riderVehicleTypeSelect = document.getElementById('rider_vehicle_type_select');
            const riderPlateInput = document.getElementById('rider_plate_input');
            const confirmRiderVehiclePlateBtn = document.getElementById('confirmRiderVehiclePlateBtn');
            const vehicleSelected = riderVehicleTypeSelect && riderVehicleTypeSelect.value !== '';
            const plateFilled = riderPlateInput && riderPlateInput.value.trim() !== '';
            confirmRiderVehiclePlateBtn.disabled = !(vehicleSelected && plateFilled);
        }
        return false;
    }
});

document.addEventListener('DOMContentLoaded', function() {
    const riderIdModalBtn = document.getElementById('rider_id_modal_btn');
    const riderIdDocumentsModal = document.getElementById('riderIdDocumentsModal');
    const cancelRiderIdDocumentsBtn = document.getElementById('cancelRiderIdDocumentsBtn');
    const confirmRiderIdDocumentsBtn = document.getElementById('confirmRiderIdDocumentsBtn');

    const riderOrcrUpload = document.getElementById('rider_orcr_upload');
    const riderOrcrContainer = document.getElementById('riderOrcrContainer');
    const riderOrcrPreview = document.getElementById('riderOrcrPreview');
    const riderDriverLicenseUpload = document.getElementById('rider_driver_license_upload');
    const riderDriverLicenseContainer = document.getElementById('riderDriverLicenseContainer');
    const riderDriverLicensePreview = document.getElementById('riderDriverLicensePreview');

    // Check if both files are uploaded
    function checkRequiredFiles() {
        const orcrUploaded = riderOrcrUpload && riderOrcrUpload.files && riderOrcrUpload.files.length > 0;
        const driverLicenseUploaded = riderDriverLicenseUpload && riderDriverLicenseUpload.files && riderDriverLicenseUpload.files.length > 0;
        confirmRiderIdDocumentsBtn.disabled = !(orcrUploaded && driverLicenseUploaded);
    }

    // Handle ORCR file upload
    if (riderOrcrContainer) {
        riderOrcrContainer.addEventListener('click', function() {
            riderOrcrUpload.click();
        });
    }

    if (riderOrcrUpload) {
        riderOrcrUpload.addEventListener('change', function(e) {
            if (this.files && this.files.length > 0) {
                const file = this.files[0];
                const reader = new FileReader();
                reader.onload = function(event) {
                    riderOrcrPreview.src = event.target.result;
                    riderOrcrPreview.style.display = 'block';
                    riderOrcrContainer.querySelector('.upload-placeholder').style.display = 'none';
                };
                reader.readAsDataURL(file);
            }
            checkRequiredFiles();
        });
    }

    // Handle Driver License file upload
    if (riderDriverLicenseContainer) {
        riderDriverLicenseContainer.addEventListener('click', function() {
            riderDriverLicenseUpload.click();
        });
    }

    if (riderDriverLicenseUpload) {
        riderDriverLicenseUpload.addEventListener('change', function(e) {
            if (this.files && this.files.length > 0) {
                const file = this.files[0];
                const reader = new FileReader();
                reader.onload = function(event) {
                    riderDriverLicensePreview.src = event.target.result;
                    riderDriverLicensePreview.style.display = 'block';
                    riderDriverLicenseContainer.querySelector('.upload-placeholder').style.display = 'none';
                };
                reader.readAsDataURL(file);
            }
            checkRequiredFiles();
        });
    }

    // Update button text with ellipsis when files change
    function updateRiderIdButtonText() {
        const orcrFileName = riderOrcrUpload && riderOrcrUpload.files && riderOrcrUpload.files.length > 0 
            ? riderOrcrUpload.files[0].name 
            : '';
        const driverLicenseFileName = riderDriverLicenseUpload && riderDriverLicenseUpload.files && riderDriverLicenseUpload.files.length > 0 
            ? riderDriverLicenseUpload.files[0].name 
            : '';

        if (orcrFileName && driverLicenseFileName) {
            riderIdModalBtn.textContent = `ORCR: ${orcrFileName} | DL: ${driverLicenseFileName}`;
            // Apply ellipsis styles
            riderIdModalBtn.style.overflow = 'hidden';
            riderIdModalBtn.style.textOverflow = 'ellipsis';
            riderIdModalBtn.style.whiteSpace = 'nowrap';
            riderIdModalBtn.style.display = 'block';
            riderIdModalBtn.style.minWidth = '0';
        }
    }

    // Open modal
    if (riderIdModalBtn) {
        riderIdModalBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('Rider ID modal button clicked');
            
            // Position modal above the button and center it
            const rect = riderIdModalBtn.getBoundingClientRect();
            const modalWidth = 500;
            const fieldCenter = rect.left + (rect.width / 2);
            const modalLeft = fieldCenter - (modalWidth / 2);
            
            riderIdDocumentsModal.style.bottom = `${window.innerHeight - rect.top + window.scrollY + 6}px`;
            riderIdDocumentsModal.style.left = `${modalLeft + window.scrollX}px`;
            riderIdDocumentsModal.style.top = 'auto';
            riderIdDocumentsModal.style.display = 'block';
            
            checkRequiredFiles();
        });
    } else {
        console.error('Rider ID modal button not found');
    }

    // Cancel button
    if (cancelRiderIdDocumentsBtn && riderIdDocumentsModal) {
        cancelRiderIdDocumentsBtn.addEventListener('click', function() {
            riderIdDocumentsModal.style.display = 'none';
        });
    }

    // Click outside closes modal
    document.addEventListener('click', function(e) {
        if (riderIdDocumentsModal && riderIdDocumentsModal.style.display === 'block') {
            if (!riderIdDocumentsModal.contains(e.target) && e.target !== riderIdModalBtn) {
                riderIdDocumentsModal.style.display = 'none';
            }
        }
    });

    // File input change handlers
    if (riderOrcrUpload) {
        riderOrcrUpload.addEventListener('change', function() {
            checkRequiredFiles();
        });
    }

    if (riderDriverLicenseUpload) {
        riderDriverLicenseUpload.addEventListener('change', function() {
            checkRequiredFiles();
        });
    }

    // Confirm button
    if (confirmRiderIdDocumentsBtn) {
        confirmRiderIdDocumentsBtn.addEventListener('click', function() {
            const orcrFile = riderOrcrUpload && riderOrcrUpload.files && riderOrcrUpload.files.length > 0 
                ? riderOrcrUpload.files[0] 
                : null;
            const driverLicenseFile = riderDriverLicenseUpload && riderDriverLicenseUpload.files && riderDriverLicenseUpload.files.length > 0 
                ? riderDriverLicenseUpload.files[0] 
                : null;

            if (orcrFile && driverLicenseFile) {
                // Store file objects globally for form submission
                riderOrcrFileObj = orcrFile;
                riderDriverLicenseFileObj = driverLicenseFile;
                
                // Update button text with ellipsis
                updateRiderIdButtonText();
                
                riderIdDocumentsModal.style.display = 'none';
            }
        });
    }

    // Vehicle & Plate Modal functionality
    const riderPlateModalBtn = document.getElementById('rider_plate_modal_btn');
    const riderVehiclePlateModal = document.getElementById('riderVehiclePlateModal');
    const cancelRiderVehiclePlateBtn = document.getElementById('cancelRiderVehiclePlateBtn');
    const confirmRiderVehiclePlateBtn = document.getElementById('confirmRiderVehiclePlateBtn');
    const riderVehicleTypeSelect = document.getElementById('rider_vehicle_type_select');
    const riderPlateInput = document.getElementById('rider_plate_input');
    const plateCharCount = document.getElementById('plateCharCount');

    // Check if both vehicle type and plate are filled
    function checkVehiclePlateFields() {
        const vehicleSelected = riderVehicleTypeSelect && riderVehicleTypeSelect.value !== '';
        const plateFilled = riderPlateInput && riderPlateInput.value.trim() !== '';
        confirmRiderVehiclePlateBtn.disabled = !(vehicleSelected && plateFilled);
    }

    // Open vehicle & plate modal
    if (riderPlateModalBtn) {
        riderPlateModalBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('Rider plate modal button clicked');
            
            // Position modal above the button and center it
            const rect = riderPlateModalBtn.getBoundingClientRect();
            const modalWidth = 500;
            const fieldCenter = rect.left + (rect.width / 2);
            const modalLeft = fieldCenter - (modalWidth / 2);
            
            riderVehiclePlateModal.style.bottom = `${window.innerHeight - rect.top + window.scrollY + 6}px`;
            riderVehiclePlateModal.style.left = `${modalLeft + window.scrollX}px`;
            riderVehiclePlateModal.style.top = 'auto';
            riderVehiclePlateModal.style.display = 'block';
            
            checkVehiclePlateFields();
        });
    } else {
        console.error('Rider plate modal button not found');
    }

    // Cancel button for vehicle & plate modal
    if (cancelRiderVehiclePlateBtn && riderVehiclePlateModal) {
        cancelRiderVehiclePlateBtn.addEventListener('click', function() {
            riderVehiclePlateModal.style.display = 'none';
        });
    }

    // Click outside closes vehicle & plate modal
    document.addEventListener('click', function(e) {
        if (riderVehiclePlateModal && riderVehiclePlateModal.style.display === 'block') {
            if (!riderVehiclePlateModal.contains(e.target) && e.target !== riderPlateModalBtn) {
                riderVehiclePlateModal.style.display = 'none';
            }
        }
    });

    // Vehicle type select change
    if (riderVehicleTypeSelect) {
        riderVehicleTypeSelect.addEventListener('change', checkVehiclePlateFields);
    }

    // Plate input change - update character count, validate, and auto-capitalize
    if (riderPlateInput) {
        riderPlateInput.addEventListener('input', function(e) {
            // Convert to uppercase
            e.target.value = e.target.value.toUpperCase();
            
            // Remove spaces and count characters
            const plateWithoutSpaces = e.target.value.replace(/\s/g, '');
            plateCharCount.textContent = plateWithoutSpaces.length;
            
            // Limit to 10 characters (excluding spaces)
            if (plateWithoutSpaces.length > 10) {
                e.target.value = e.target.value.substring(0, e.target.value.length - 1);
                plateCharCount.textContent = e.target.value.replace(/\s/g, '').length;
            }
            
            checkVehiclePlateFields();
        });
    }

    // Confirm button for vehicle & plate modal
    if (confirmRiderVehiclePlateBtn) {
        confirmRiderVehiclePlateBtn.addEventListener('click', function() {
            const vehicleType = riderVehicleTypeSelect ? riderVehicleTypeSelect.value : '';
            const plateNumber = riderPlateInput ? riderPlateInput.value : '';

            if (vehicleType && plateNumber.trim()) {
                // Get vehicle type label
                const vehicleOption = riderVehicleTypeSelect.options[riderVehicleTypeSelect.selectedIndex];
                const vehicleLabel = vehicleOption ? vehicleOption.text : vehicleType;
                
                // Store values globally for form submission
                riderVehicleType = vehicleType;
                riderPlateNumber = plateNumber;
                
                // Update button text to show selected values with ellipsis
                riderPlateModalBtn.textContent = `${vehicleLabel} - ${plateNumber}`;
                
                // Store values in hidden fields
                const vehicleTypeHidden = document.getElementById('rider_vehicle_type_hidden');
                const plateNumberHidden = document.getElementById('rider_plate_number_hidden');
                if (vehicleTypeHidden) vehicleTypeHidden.value = vehicleType;
                if (plateNumberHidden) plateNumberHidden.value = plateNumber;
                
                riderVehiclePlateModal.style.display = 'none';
            }
        });
    }
});
