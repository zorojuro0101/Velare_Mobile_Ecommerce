// seller_product_sales.js
// Handles product sales page functionality with interactive charts

document.addEventListener('DOMContentLoaded', function() {
    let unitsSoldChart = null;
    let revenueTrendChart = null;
    let currentSalesData = null;
    let currentChartData = null;

    // Set default date range (last 30 days)
    const today = new Date();
    const thirtyDaysAgo = new Date(today);
    thirtyDaysAgo.setDate(today.getDate() - 30);
    
    const dateFromInput = document.getElementById('dateFrom');
    const dateToInput = document.getElementById('dateTo');
    
    if (dateFromInput && dateToInput) {
        dateFromInput.value = thirtyDaysAgo.toISOString().split('T')[0];
        dateToInput.value = today.toISOString().split('T')[0];
    }

    // Initialize page
    loadSalesData();
    
    // Load Product Sold data
    fetchAndDisplaySoldProducts();
    attachProductSoldEventListeners();

    // Load sales data from API
    async function loadSalesData() {
        try {
            const dateFrom = dateFromInput ? dateFromInput.value : '';
            const dateTo = dateToInput ? dateToInput.value : '';
            
            // Build query parameters
            let queryParams = '';
            if (dateFrom && dateTo) {
                queryParams = `?dateFrom=${dateFrom}&dateTo=${dateTo}`;
            }
            
            // Fetch summary data
            const summaryResponse = await fetch(`/seller/api/sales-summary${queryParams}`);
            const summaryData = await summaryResponse.json();
            
            // Fetch sales details
            const sortParam = queryParams ? '&sort=most-sold' : '?sort=most-sold';
            const detailsResponse = await fetch(`/seller/api/sales-details${queryParams}${sortParam}`);
            const detailsData = await detailsResponse.json();
            
            // Fetch chart data with date range
            const chartsResponse = await fetch(`/seller/api/sales-charts${queryParams}`);
            const chartsData = await chartsResponse.json();
            
            currentSalesData = {
                summary: summaryData,
                details: detailsData.sales,
                charts: chartsData
            };
            
            currentChartData = chartsData;
            
            // Update UI
            updateSummaryCards(summaryData);
            updateSalesTable(detailsData.sales);
            updateChartTitles(dateFrom, dateTo);
            initializeCharts(chartsData);
            
        } catch (error) {
            console.error('Error loading sales data:', error);
            showErrorMessage('Failed to load sales data');
        }
    }

    // Update chart titles with date range
    function updateChartTitles(dateFrom, dateTo) {
        if (dateFrom && dateTo) {
            const fromDate = new Date(dateFrom);
            const toDate = new Date(dateTo);
            
            const formatDate = (date) => {
                return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
            };
            
            const dateRangeText = `${formatDate(fromDate)} - ${formatDate(toDate)}`;
            
            const unitsChartInfo = document.getElementById('unitsChartInfo');
            const revenueChartInfo = document.getElementById('revenueChartInfo');
            const unitsChartLabel = document.getElementById('unitsChartLabel');
            const revenueChartLabel = document.getElementById('revenueChartLabel');
            
            if (unitsChartInfo) {
                unitsChartInfo.textContent = dateRangeText;
            }
            
            if (revenueChartInfo) {
                revenueChartInfo.textContent = dateRangeText;
            }
            
            // Update chart labels based on current chart data
            if (currentChartData) {
                if (unitsChartLabel && currentChartData.units && currentChartData.units.label) {
                    unitsChartLabel.textContent = currentChartData.units.label;
                }
                
                if (revenueChartLabel && currentChartData.revenue && currentChartData.revenue.label) {
                    revenueChartLabel.textContent = currentChartData.revenue.label;
                }
            }
        }
    }

    // Update summary cards
    function updateSummaryCards(data) {
        const totalProductsSold = document.getElementById('totalProductsSold');
        const totalRevenue = document.getElementById('totalRevenue');
        const totalCommission = document.getElementById('totalCommission');
        const bestSellingProduct = document.getElementById('bestSellingProduct');
        const highlightStats = document.querySelector('.highlight-stats');
        
        if (totalProductsSold) {
            totalProductsSold.textContent = data.total_products_sold || 0;
        }
        
        if (totalRevenue) {
            totalRevenue.textContent = '₱' + (data.total_revenue || 0).toLocaleString('en-PH', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });
        }
        
        if (totalCommission) {
            totalCommission.textContent = '₱' + (data.total_commission || 0).toLocaleString('en-PH', {
                minimumFractionDigits: 2,
                maximumFractionDigits: 2
            });
        }
        
        if (bestSellingProduct && data.best_seller) {
            bestSellingProduct.textContent = data.best_seller.product_name || 'N/A';
        }
        
        if (highlightStats && data.best_seller) {
            highlightStats.innerHTML = `
                <span class="highlight-stat">
                    <i class="bi bi-box"></i>
                    <strong>${data.best_seller.units_sold || 0} units</strong> sold
                </span>
            `;
        }
    }

    // Event listeners
    const sortByFilter = document.getElementById('sortByFilter');
    const exportSalesBtn = document.getElementById('exportSalesBtn');

    // Add event listeners to date inputs
    if (dateFromInput) {
        dateFromInput.addEventListener('change', function() {
            if (dateToInput && dateToInput.value) {
                loadSalesData();
            }
        });
    }

    if (dateToInput) {
        dateToInput.addEventListener('change', function() {
            if (dateFromInput && dateFromInput.value) {
                loadSalesData();
            }
        });
    }

    if (sortByFilter) {
        sortByFilter.addEventListener('change', async function() {
            const sortBy = this.value;
            try {
                const dateFrom = dateFromInput ? dateFromInput.value : '';
                const dateTo = dateToInput ? dateToInput.value : '';
                
                let queryParams = '';
                if (dateFrom && dateTo) {
                    queryParams = `?dateFrom=${dateFrom}&dateTo=${dateTo}&sort=${sortBy}`;
                } else {
                    queryParams = `?sort=${sortBy}`;
                }
                
                const response = await fetch(`/seller/api/sales-details${queryParams}`);
                const data = await response.json();
                updateSalesTable(data.sales);
            } catch (error) {
                console.error('Error sorting sales data:', error);
            }
        });
    }

    if (exportSalesBtn) {
        exportSalesBtn.addEventListener('click', function() {
            exportSalesData();
        });
    }

    // Initialize charts with Chart.js
    function initializeCharts(chartsData) {
        const unitsCtx = document.getElementById('unitsSoldChart');
        const revenueCtx = document.getElementById('revenueTrendChart');

        if (unitsCtx && chartsData && chartsData.units) {
            // Destroy existing chart if it exists
            if (unitsSoldChart) {
                unitsSoldChart.destroy();
            }
            
            unitsSoldChart = new Chart(unitsCtx, {
                type: 'bar',
                data: {
                    labels: chartsData.units.labels.length > 0 ? chartsData.units.labels : ['No Data'],
                    datasets: [{
                        label: chartsData.units.label || 'Units Sold',
                        data: chartsData.units.data.length > 0 ? chartsData.units.data : [0],
                        backgroundColor: 'rgba(211, 189, 155, 0.8)',
                        borderColor: 'rgba(211, 189, 155, 1)',
                        borderWidth: 2,
                        borderRadius: 0,
                        hoverBackgroundColor: 'rgba(191, 161, 74, 0.9)',
                        hoverBorderColor: 'rgba(191, 161, 74, 1)'
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            backgroundColor: 'rgba(44, 34, 54, 0.95)',
                            titleFont: {
                                family: "'Playfair Display', serif",
                                size: 14
                            },
                            bodyFont: {
                                family: "'Montserrat', sans-serif",
                                size: 13
                            },
                            padding: 12,
                            borderColor: 'rgba(211, 189, 155, 0.5)',
                            borderWidth: 1,
                            callbacks: {
                                label: function(context) {
                                    return 'Units Sold: ' + context.parsed.y;
                                }
                            }
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                font: {
                                    family: "'Montserrat', sans-serif",
                                    size: 11
                                },
                                color: '#6d6552'
                            },
                            grid: {
                                color: 'rgba(224, 215, 198, 0.3)'
                            }
                        },
                        x: {
                            ticks: {
                                font: {
                                    family: "'Montserrat', sans-serif",
                                    size: 11
                                },
                                color: '#6d6552'
                            },
                            grid: {
                                display: false
                            }
                        }
                    }
                }
            });
        }

        if (revenueCtx && chartsData && chartsData.revenue) {
            // Destroy existing chart if it exists
            if (revenueTrendChart) {
                revenueTrendChart.destroy();
            }
            
            revenueTrendChart = new Chart(revenueCtx, {
                type: 'line',
                data: {
                    labels: chartsData.revenue.labels.length > 0 ? chartsData.revenue.labels : ['No Data'],
                    datasets: [{
                        label: chartsData.revenue.label || 'Revenue',
                        data: chartsData.revenue.data.length > 0 ? chartsData.revenue.data : [0],
                        backgroundColor: 'rgba(191, 161, 74, 0.1)',
                        borderColor: 'rgba(191, 161, 74, 1)',
                        borderWidth: 3,
                        fill: true,
                        tension: 0.4,
                        pointBackgroundColor: 'rgba(191, 161, 74, 1)',
                        pointBorderColor: '#fff',
                        pointBorderWidth: 2,
                        pointRadius: 5,
                        pointHoverRadius: 7,
                        pointHoverBackgroundColor: 'rgba(212, 175, 55, 1)',
                        pointHoverBorderColor: '#fff',
                        pointHoverBorderWidth: 3
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        legend: {
                            display: false
                        },
                        tooltip: {
                            backgroundColor: 'rgba(44, 34, 54, 0.95)',
                            titleFont: {
                                family: "'Playfair Display', serif",
                                size: 14
                            },
                            bodyFont: {
                                family: "'Montserrat', sans-serif",
                                size: 13
                            },
                            padding: 12,
                            borderColor: 'rgba(211, 189, 155, 0.5)',
                            borderWidth: 1,
                            callbacks: {
                                label: function(context) {
                                    return 'Revenue: ₱' + context.parsed.y.toLocaleString();
                                }
                            }
                        }
                    },
                    scales: {
                        y: {
                            beginAtZero: true,
                            ticks: {
                                font: {
                                    family: "'Montserrat', sans-serif",
                                    size: 11
                                },
                                color: '#6d6552',
                                callback: function(value) {
                                    return '₱' + (value / 1000) + 'k';
                                }
                            },
                            grid: {
                                color: 'rgba(224, 215, 198, 0.3)'
                            }
                        },
                        x: {
                            ticks: {
                                font: {
                                    family: "'Montserrat', sans-serif",
                                    size: 11
                                },
                                color: '#6d6552'
                            },
                            grid: {
                                display: false
                            }
                        }
                    }
                }
            });
        }
    }

    // Update sales table
    function updateSalesTable(sales) {
        const tableBody = document.getElementById('salesTableBody');
        if (!tableBody) return;
        
        tableBody.innerHTML = '';
        
        if (!sales || sales.length === 0) {
            tableBody.innerHTML = `
                <tr class="table-row">
                    <td class="table-cell" colspan="4" style="text-align: center; padding: 40px;">
                        No sales data available for this period
                    </td>
                </tr>
            `;
            return;
        }
        
        sales.forEach(sale => {
            const row = document.createElement('tr');
            row.className = 'table-row';
            row.innerHTML = `
                <td class="table-cell">${sale.product_name}</td>
                <td class="table-cell">${sale.units_sold}</td>
                <td class="table-cell">₱${sale.revenue.toLocaleString('en-PH', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                })}</td>
                <td class="table-cell">${sale.date_range}</td>
            `;
            tableBody.appendChild(row);
        });
    }
    
    // Show error message
    function showErrorMessage(message) {
        const tableBody = document.getElementById('salesTableBody');
        if (tableBody) {
            tableBody.innerHTML = `
                <tr class="table-row">
                    <td class="table-cell" colspan="4" style="text-align: center; padding: 40px; color: #dc3545;">
                        ${message}
                    </td>
                </tr>
            `;
        }
    }

    // Export sales data to Excel
    function exportSalesData() {
        // Get current date range
        const dateFrom = document.getElementById('dateFrom').value;
        const dateTo = document.getElementById('dateTo').value;
        
        // Build export URL with date parameters
        let exportUrl = '/seller/product-sales/export-excel';
        const params = new URLSearchParams();
        
        if (dateFrom) params.append('dateFrom', dateFrom);
        if (dateTo) params.append('dateTo', dateTo);
        
        if (params.toString()) {
            exportUrl += '?' + params.toString();
        }
        
        // Trigger download
        window.location.href = exportUrl;
        
        // Show success message
        showExportSuccess();
    }

    // Show export success notification
    function showExportSuccess() {
        const exportBtn = document.getElementById('exportSalesBtn');
        if (!exportBtn) return;
        
        const originalHTML = exportBtn.innerHTML;
        exportBtn.innerHTML = '<i class="bi bi-check-circle-fill"></i> Exported Successfully!';
        exportBtn.style.background = 'linear-gradient(135deg, #28a745 0%, #20873a 100%)';
        exportBtn.disabled = true;
        
        setTimeout(() => {
            exportBtn.innerHTML = originalHTML;
            exportBtn.style.background = 'linear-gradient(135deg, #D3BD9B 0%, #c4a882 100%)';
            exportBtn.disabled = false;
        }, 2000);
    }

    // Make charts responsive to window resize
    window.addEventListener('resize', function() {
        if (unitsSoldChart) {
            unitsSoldChart.resize();
        }
        if (revenueTrendChart) {
            revenueTrendChart.resize();
        }
    });
});

    // ========== PRODUCT SOLD FUNCTIONS ==========
    
    function fetchAndDisplaySoldProducts() {
        fetch('/api/products/sold')
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    displaySoldProducts(data.sold_orders);
                } else {
                    console.error('Error loading sold products:', data.message);
                    showEmptySoldProducts();
                }
            })
            .catch(error => {
                console.error('Error fetching sold products:', error);
                showEmptySoldProducts();
            });
    }
    
    function displaySoldProducts(soldOrders) {
        const tbody = document.getElementById('productSoldTableBody');
        if (!tbody) return;
        
        if (soldOrders.length === 0) {
            showEmptySoldProducts();
            return;
        }
        
        tbody.innerHTML = soldOrders.map((order, index) => {
            const receivedDate = new Date(order.order_received_date).toLocaleDateString('en-US', {
                year: 'numeric',
                month: 'short',
                day: 'numeric'
            });
            
            const orderTotal = parseFloat(order.order_total);
            const commission = parseFloat(order.commission_amount);
            
            // Build products list HTML
            const productsHTML = order.items.map(item => {
                const variant = [];
                if (item.variant_color) variant.push(item.variant_color);
                if (item.variant_size) variant.push(item.variant_size);
                const variantText = variant.length > 0 ? ` (${variant.join(', ')})` : '';
                
                return `
                    <div class="product-item-compact">
                        <span class="product-name">${item.product_name}</span>
                        ${variantText ? `<span class="product-variant">${variantText}</span>` : ''}
                        <span class="product-qty">× ${item.quantity}</span>
                    </div>
                `;
            }).join('');
            
            return `
                <tr class="table-row">
                    <td class="table-cell">#${String(index + 1).padStart(3, '0')}</td>
                    <td class="table-cell">
                        <div class="products-list">
                            ${productsHTML}
                        </div>
                    </td>
                    <td class="table-cell">${receivedDate}</td>
                    <td class="table-cell">${order.buyer_name}</td>
                    <td class="table-cell price-positive">+₱${orderTotal.toLocaleString('en-PH', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                    <td class="table-cell commission-negative">-₱${commission.toLocaleString('en-PH', {minimumFractionDigits: 2, maximumFractionDigits: 2})}</td>
                </tr>
            `;
        }).join('');
    }
    
    function showEmptySoldProducts() {
        const tbody = document.getElementById('productSoldTableBody');
        if (!tbody) return;
        
        tbody.innerHTML = `
            <tr class="table-row">
                <td class="table-cell" colspan="6" style="text-align: center; padding: 40px; color: #666;">
                    <i class="bi bi-inbox" style="font-size: 48px; display: block; margin-bottom: 16px;"></i>
                    <p>No sold products yet</p>
                </td>
            </tr>
        `;
    }

    function attachProductSoldEventListeners() {
        // Search functionality
        const productSoldSearch = document.getElementById('productSoldSearch');
        if (productSoldSearch) {
            productSoldSearch.addEventListener('input', function() {
                filterSoldProducts();
            });
        }

        // Date range filter functionality
        const productSoldDateFrom = document.getElementById('productSoldDateFrom');
        const productSoldDateTo = document.getElementById('productSoldDateTo');
        
        if (productSoldDateFrom) {
            productSoldDateFrom.addEventListener('change', function() {
                filterSoldProducts();
            });
        }
        
        if (productSoldDateTo) {
            productSoldDateTo.addEventListener('change', function() {
                filterSoldProducts();
            });
        }
    }
    
    function filterSoldProducts() {
        const searchTerm = document.getElementById('productSoldSearch')?.value.toLowerCase() || '';
        const dateFrom = document.getElementById('productSoldDateFrom')?.value || '';
        const dateTo = document.getElementById('productSoldDateTo')?.value || '';
        const rows = document.querySelectorAll('#productSoldTableBody tr');
        
        rows.forEach(row => {
            const productName = row.cells[1]?.textContent.toLowerCase() || '';
            const buyer = row.cells[3]?.textContent.toLowerCase() || '';
            const dateText = row.cells[2]?.textContent || '';
            
            // Check search match
            const searchMatch = !searchTerm || 
                productName.includes(searchTerm) || 
                buyer.includes(searchTerm);
            
            // Check date range filter
            let dateMatch = true;
            if ((dateFrom || dateTo) && dateText) {
                const rowDate = new Date(dateText);
                
                if (dateFrom && dateTo) {
                    // Both dates specified - check if within range
                    const fromDate = new Date(dateFrom);
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999); // Include the entire end date
                    dateMatch = rowDate >= fromDate && rowDate <= toDate;
                } else if (dateFrom) {
                    // Only from date specified
                    const fromDate = new Date(dateFrom);
                    dateMatch = rowDate >= fromDate;
                } else if (dateTo) {
                    // Only to date specified
                    const toDate = new Date(dateTo);
                    toDate.setHours(23, 59, 59, 999);
                    dateMatch = rowDate <= toDate;
                }
            }
            
            // Show/hide row based on filters
            if (searchMatch && dateMatch) {
                row.style.display = '';
            } else {
                row.style.display = 'none';
            }
        });
    }

