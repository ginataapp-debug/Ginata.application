-- Ginata Property Management - Complete PostgreSQL Schema for Supabase
-- Run this script in the Supabase SQL Editor

CREATE TABLE organizations (
	id VARCHAR(36) NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	tax_id VARCHAR(100), 
	phone VARCHAR(50), 
	email VARCHAR(255), 
	address VARCHAR(255), 
	city VARCHAR(100), 
	country VARCHAR(100) NOT NULL, 
	logo_url VARCHAR(500), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE TABLE audit_logs (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	entity_type VARCHAR(50) NOT NULL, 
	entity_id VARCHAR(36) NOT NULL, 
	action VARCHAR(100) NOT NULL, 
	actor_name VARCHAR(100) NOT NULL, 
	details JSON, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE guests (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	first_name VARCHAR(100) NOT NULL, 
	last_name VARCHAR(100) NOT NULL, 
	email VARCHAR(255), 
	phone VARCHAR(50), 
	id_type VARCHAR(50), 
	id_number_masked VARCHAR(100), 
	nationality VARCHAR(100), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE org_sequences (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	series_key VARCHAR(50) NOT NULL, 
	year INTEGER NOT NULL, 
	current_val INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_series_year UNIQUE (organization_id, series_key, year), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE properties (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	slug VARCHAR(255) NOT NULL, 
	address VARCHAR(255), 
	city VARCHAR(100), 
	country VARCHAR(100) NOT NULL, 
	default_nightly_rate NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	cleaning_fee NUMERIC(12, 2) NOT NULL, 
	tax_rate NUMERIC(5, 4) NOT NULL, 
	image_url VARCHAR(500), 
	airbnb_ical_url VARCHAR(500), 
	booking_com_ical_url VARCHAR(500), 
	ical_feed_token VARCHAR(100) NOT NULL, 
	last_synced_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_property_slug UNIQUE (organization_id, slug), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE
);

CREATE TABLE document_templates (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36), 
	name VARCHAR(255) NOT NULL, 
	layout_style VARCHAR(50) NOT NULL, 
	primary_color VARCHAR(20) NOT NULL, 
	secondary_color VARCHAR(20) NOT NULL, 
	font_family VARCHAR(50) NOT NULL, 
	logo_url VARCHAR(500), 
	header_text TEXT, 
	footer_text TEXT, 
	payment_instructions TEXT, 
	tax_notes TEXT, 
	is_default BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE CASCADE
);

CREATE TABLE guest_forms (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36), 
	mode VARCHAR(50) NOT NULL, 
	title VARCHAR(255) NOT NULL, 
	description TEXT, 
	is_active BOOLEAN NOT NULL, 
	fields_config JSON, 
	google_form_id VARCHAR(255), 
	google_sheet_id VARCHAR(255), 
	google_connected_email VARCHAR(255), 
	google_sync_status VARCHAR(50) NOT NULL, 
	google_last_sync_at TIMESTAMP WITHOUT TIME ZONE, 
	google_last_error TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE SET NULL
);

CREATE TABLE property_inventory_items (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36) NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	category VARCHAR(100) NOT NULL, 
	quantity INTEGER NOT NULL, 
	condition VARCHAR(50) NOT NULL, 
	room_location VARCHAR(100), 
	replacement_cost_kes NUMERIC(12, 2) NOT NULL, 
	last_inspected_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE CASCADE
);

CREATE TABLE property_units (
	id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36) NOT NULL, 
	name VARCHAR(255) NOT NULL, 
	max_guests INTEGER NOT NULL, 
	bedrooms INTEGER NOT NULL, 
	bathrooms INTEGER NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE CASCADE
);

CREATE TABLE reservations (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36) NOT NULL, 
	unit_id VARCHAR(36), 
	primary_guest_id VARCHAR(36) NOT NULL, 
	booking_reference VARCHAR(100), 
	booking_source VARCHAR(50) NOT NULL, 
	reservation_status VARCHAR(50) NOT NULL, 
	payment_status VARCHAR(50) NOT NULL, 
	guest_info_status VARCHAR(50) NOT NULL, 
	check_in_date DATE NOT NULL, 
	check_out_date DATE NOT NULL, 
	check_in_time VARCHAR(10) NOT NULL, 
	check_out_time VARCHAR(10) NOT NULL, 
	number_of_guests INTEGER NOT NULL, 
	number_of_nights INTEGER NOT NULL, 
	nightly_rate NUMERIC(12, 2) NOT NULL, 
	base_amount NUMERIC(12, 2) NOT NULL, 
	cleaning_fee NUMERIC(12, 2) NOT NULL, 
	service_fee NUMERIC(12, 2) NOT NULL, 
	discount_amount NUMERIC(12, 2) NOT NULL, 
	tax_amount NUMERIC(12, 2) NOT NULL, 
	total_amount NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	amount_paid NUMERIC(12, 2) NOT NULL, 
	balance_due NUMERIC(12, 2) NOT NULL, 
	has_agent BOOLEAN NOT NULL, 
	agent_name VARCHAR(200), 
	agent_phone VARCHAR(50), 
	agent_commission_percent NUMERIC(5, 2) NOT NULL, 
	agent_commission_amount NUMERIC(12, 2) NOT NULL, 
	net_host_amount NUMERIC(12, 2) NOT NULL, 
	internal_notes TEXT, 
	special_requests TEXT, 
	has_conflict BOOLEAN NOT NULL, 
	conflict_override_reason TEXT, 
	conflict_overridden_by VARCHAR(100), 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE CASCADE, 
	FOREIGN KEY(unit_id) REFERENCES property_units (id) ON DELETE SET NULL, 
	FOREIGN KEY(primary_guest_id) REFERENCES guests (id) ON DELETE RESTRICT
);

CREATE TABLE expenses (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36), 
	title VARCHAR(255) NOT NULL, 
	category VARCHAR(100) NOT NULL, 
	amount NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	expense_date DATE NOT NULL, 
	vendor_name VARCHAR(200), 
	receipt_reference VARCHAR(100), 
	payment_method VARCHAR(50) NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE CASCADE, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE SET NULL
);

CREATE TABLE guest_form_submissions (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36) NOT NULL, 
	token VARCHAR(100) NOT NULL, 
	token_expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	token_revoked BOOLEAN NOT NULL, 
	form_status VARCHAR(50) NOT NULL, 
	submitted_at TIMESTAMP WITHOUT TIME ZONE, 
	guest_name VARCHAR(200), 
	guest_email VARCHAR(255), 
	guest_phone VARCHAR(50), 
	eta VARCHAR(50), 
	flight_number VARCHAR(50), 
	transport_mode VARCHAR(50), 
	dietary_requirements TEXT, 
	special_requests TEXT, 
	id_type VARCHAR(50), 
	id_number VARCHAR(100), 
	id_photo_url VARCHAR(500), 
	companion_details JSON, 
	raw_data JSON, 
	review_notes TEXT, 
	reviewed_by VARCHAR(100), 
	reviewed_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE CASCADE
);

CREATE TABLE invoices (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36) NOT NULL, 
	invoice_number VARCHAR(100) NOT NULL, 
	document_type VARCHAR(50) NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	issue_date DATE NOT NULL, 
	due_date DATE NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	supplier_name VARCHAR(255) NOT NULL, 
	supplier_tax_pin VARCHAR(100), 
	supplier_address VARCHAR(255), 
	supplier_email VARCHAR(255), 
	supplier_phone VARCHAR(50), 
	supplier_logo_url VARCHAR(500), 
	billing_name VARCHAR(200) NOT NULL, 
	billing_email VARCHAR(255), 
	billing_phone VARCHAR(50), 
	billing_company_name VARCHAR(255), 
	billing_company_pin VARCHAR(100), 
	billing_company_address VARCHAR(255), 
	subtotal NUMERIC(12, 2) NOT NULL, 
	discount_total NUMERIC(12, 2) NOT NULL, 
	tax_total NUMERIC(12, 2) NOT NULL, 
	grand_total NUMERIC(12, 2) NOT NULL, 
	amount_paid NUMERIC(12, 2) NOT NULL, 
	balance_due NUMERIC(12, 2) NOT NULL, 
	payment_terms TEXT, 
	payment_instructions TEXT, 
	notes TEXT, 
	footer TEXT, 
	version INTEGER NOT NULL, 
	issued_at TIMESTAMP WITHOUT TIME ZONE, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_invoice_num UNIQUE (organization_id, invoice_number), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE CASCADE
);

CREATE TABLE message_threads (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	property_id VARCHAR(36), 
	reservation_id VARCHAR(36), 
	channel VARCHAR(50) NOT NULL, 
	participant_name VARCHAR(200) NOT NULL, 
	participant_contact VARCHAR(200), 
	status VARCHAR(50) NOT NULL, 
	last_message_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(property_id) REFERENCES properties (id) ON DELETE SET NULL, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE SET NULL
);

CREATE TABLE reservation_guests (
	id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36) NOT NULL, 
	name VARCHAR(200) NOT NULL, 
	email VARCHAR(255), 
	phone VARCHAR(50), 
	is_primary BOOLEAN NOT NULL, 
	age_category VARCHAR(20) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE CASCADE
);

CREATE TABLE credit_notes (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	invoice_id VARCHAR(36) NOT NULL, 
	credit_note_number VARCHAR(100) NOT NULL, 
	reason TEXT NOT NULL, 
	amount NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	issued_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_credit_note_num UNIQUE (organization_id, credit_note_number), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);

CREATE TABLE invoice_line_items (
	id VARCHAR(36) NOT NULL, 
	invoice_id VARCHAR(36) NOT NULL, 
	position INTEGER NOT NULL, 
	description VARCHAR(255) NOT NULL, 
	quantity NUMERIC(10, 2) NOT NULL, 
	unit_price NUMERIC(12, 2) NOT NULL, 
	tax_rate NUMERIC(5, 4) NOT NULL, 
	tax_amount NUMERIC(12, 2) NOT NULL, 
	discount_amount NUMERIC(12, 2) NOT NULL, 
	total_amount NUMERIC(12, 2) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);

CREATE TABLE messages (
	id VARCHAR(36) NOT NULL, 
	thread_id VARCHAR(36) NOT NULL, 
	sender_type VARCHAR(50) NOT NULL, 
	sender_name VARCHAR(200) NOT NULL, 
	content TEXT NOT NULL, 
	is_read BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(thread_id) REFERENCES message_threads (id) ON DELETE CASCADE
);

CREATE TABLE payments (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36) NOT NULL, 
	invoice_id VARCHAR(36), 
	amount NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	payment_method VARCHAR(50) NOT NULL, 
	transaction_reference VARCHAR(100), 
	is_verified BOOLEAN NOT NULL, 
	verification_source VARCHAR(50) NOT NULL, 
	payment_date TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	notes TEXT, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE CASCADE, 
	FOREIGN KEY(invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
);

CREATE TABLE payment_allocations (
	id VARCHAR(36) NOT NULL, 
	payment_id VARCHAR(36) NOT NULL, 
	invoice_id VARCHAR(36) NOT NULL, 
	allocated_amount NUMERIC(12, 2) NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(payment_id) REFERENCES payments (id) ON DELETE CASCADE, 
	FOREIGN KEY(invoice_id) REFERENCES invoices (id) ON DELETE CASCADE
);

CREATE TABLE receipts (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	payment_id VARCHAR(36) NOT NULL, 
	receipt_number VARCHAR(100) NOT NULL, 
	receipt_date DATE NOT NULL, 
	amount_received NUMERIC(12, 2) NOT NULL, 
	currency VARCHAR(10) NOT NULL, 
	payment_method VARCHAR(50) NOT NULL, 
	transaction_reference VARCHAR(100), 
	remaining_balance NUMERIC(12, 2) NOT NULL, 
	issued_to_name VARCHAR(200) NOT NULL, 
	issued_by_name VARCHAR(200) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_org_receipt_num UNIQUE (organization_id, receipt_number), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	UNIQUE (payment_id), 
	FOREIGN KEY(payment_id) REFERENCES payments (id) ON DELETE CASCADE
);

CREATE TABLE generated_documents (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	reservation_id VARCHAR(36) NOT NULL, 
	invoice_id VARCHAR(36), 
	receipt_id VARCHAR(36), 
	document_type VARCHAR(50) NOT NULL, 
	file_format VARCHAR(10) NOT NULL, 
	file_path VARCHAR(500) NOT NULL, 
	file_name VARCHAR(255) NOT NULL, 
	file_size INTEGER NOT NULL, 
	version INTEGER NOT NULL, 
	secure_token VARCHAR(100) NOT NULL, 
	token_expires_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	is_revoked BOOLEAN NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(reservation_id) REFERENCES reservations (id) ON DELETE CASCADE, 
	FOREIGN KEY(invoice_id) REFERENCES invoices (id) ON DELETE SET NULL, 
	FOREIGN KEY(receipt_id) REFERENCES receipts (id) ON DELETE SET NULL
);

CREATE TABLE document_delivery_attempts (
	id VARCHAR(36) NOT NULL, 
	organization_id VARCHAR(36) NOT NULL, 
	document_id VARCHAR(36) NOT NULL, 
	channel VARCHAR(50) NOT NULL, 
	recipient VARCHAR(255) NOT NULL, 
	status VARCHAR(50) NOT NULL, 
	error_message TEXT, 
	attempted_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	delivered_at TIMESTAMP WITHOUT TIME ZONE, 
	PRIMARY KEY (id), 
	FOREIGN KEY(organization_id) REFERENCES organizations (id) ON DELETE CASCADE, 
	FOREIGN KEY(document_id) REFERENCES generated_documents (id) ON DELETE CASCADE
);

